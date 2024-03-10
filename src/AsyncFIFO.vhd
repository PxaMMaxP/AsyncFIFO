----------------------------------------------------------------------------------
--@ - Name:     **Asynchronous FIFO** <br>
--@ - Version:  1.1.1 <br>
--@ - Author:   __Maximilian Passarello ([Blog](mpassarello.de))__ <br>
--@ - License:  [MIT](LICENSE) <br>
--@               
--@             Asynchronous FIFO with Gray Code Read & Write Pointer.
--@             
--@ History:
--@ - 1.1.1 (2024-03-10) Complete overhaul of AsyncFIFO: <br>
--@                      *Added GrayCounter as a component <br>
--@                      *Optimized port definitions <br>
--@                      *Added timing diagrams <br>
--@                      *Create async. Flag generation <br>
--@ - 1.1.0 (2009-05-16) Initial version
----------------------------------------------------------------------------------
--@ ## Timing Diagrams:
--@ {
--@     "signal": [
--@         {
--@             "name": "WriteCLK",
--@             "wave": "p......",
--@             "phase": 1.0,
--@             "period": 2
--@         },
--@         {
--@             "name": "WriteRST",
--@             "wave": "x0..........."
--@         },
--@         {
--@             "name": "WriteCE",
--@             "wave": "x1..........."
--@         },
--@         {
--@             "name": "WriteEnable",
--@             "wave": "01.......x..."
--@         },
--@         {
--@             "name": "DataIn",
--@             "wave": "x=.=.=.=.x...",
--@             "node": ".............",
--@             "data": "First Second Third Fourth"
--@         },
--@         {
--@             "name": "FullFlag",
--@             "wave": "0........1..."
--@         }
--@     ],
--@     "head": {
--@         "text": "Write Cycles"
--@     },
--@     "foot": {
--@         "text": "Four write cycles with transition to full FIFO."
--@     }
--@ }
--@ {
--@     "signal": [
--@         {
--@             "name": "ReadCLK",
--@             "wave": "p......",
--@             "period": 2
--@         },
--@         {
--@             "name": "ReadRST",
--@             "wave": "x0............"
--@         },
--@         {
--@             "name": "ReadCE",
--@             "wave": "x1............"
--@         },
--@         {
--@             "name": "ReadEnable",
--@             "wave": "0..1.......0.."
--@         },
--@         {
--@             "name": "DataOut",
--@             "wave": "xxxx=.=.=.=.xx",
--@             "node": ".............",
--@             "data": "First Second Third Fourth"
--@         },
--@         {
--@             "name": "EmptyFlag",
--@             "wave": "1.0.......1..."
--@         }
--@     ],
--@     "head": {
--@         "text": "Read Cycles"
--@     },
--@     "foot": {
--@         "text": "Four read cycles with transition to empty FIFO."
--@     }
--@ }
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity AsyncFIFO is
    generic (
        --@ FIFO Word width: Data width of the FIFO
        Width : integer := 32;
        --@ FIFO depth: Number of words the FIFO can store
        Depth : integer := 4;
        --@ Implementation of the RAM: "Block" or "Distributed"
        RamTypeFifo : string := "Distributed"
    );
    port (
        --@ @virtualbus Write-Interface @dir in FIFO write interface
        --@ Write clock; indipendent from the read clock. **Rising edge sensitive**
        WriteCLK : in std_logic;
        --@ Write reset; synchronous reset. **Active high**
        WriteRST : in std_logic;
        --@ Write clock enable: Used for the `Write`- and `WriteGrayCounter`-process. **Active high**
        WriteCE : in std_logic;
        --@ Data input: Must be valid at the rising edge of the write clock if the write enable signal is set.
        DataIn : in std_logic_vector(Width - 1 downto 0);
        --@ Enable the write of the data to the FIFO, if the FIFO is not full. **Active high**
        WriteEnable : in std_logic;
        --@ Full flag: Indicates if the FIFO is full. **Active high**
        FullFlag : out std_logic;
        --@ @end
        --@ @virtualbus Read-Interface @dir out FIFO read interface
        --@ Read clock; indipendent from the write clock. **Rising edge sensitive**
        ReadCLK : in std_logic;
        --@ Read reset; synchronous reset. **Active high**
        ReadRST : in std_logic;
        --@ Read clock enable: Used for the `Read`- and `ReadGrayCounter`-process. **Active high**
        ReadCE : in std_logic;
        --@ Data output: The data is valid at the rising edge of the read clock
        --@ one cycle after the read enable signal is set.
        DataOut : out std_logic_vector(Width - 1 downto 0);
        --@ Enable the read of the data from the FIFO, if the FIFO is not empty. **Active high**
        ReadEnable : in std_logic;
        --@ Empty flag: Indicates if the FIFO is empty. **Active high**
        EmptyFlag : out std_logic
        --@ @end
    );
end AsyncFIFO;

architecture Behavioral of AsyncFIFO is

    component GrayCounter
        generic (
            Width             : integer;
            InitialValue      : integer;
            ResetValue        : integer;
            CountingDirection : string;
            LookAhead         : integer
        );
        port (
            CLK                       : in std_logic;
            CE                        : in std_logic;
            RST                       : in std_logic;
            CountEnable               : in std_logic;
            GrayCounterValue          : out std_logic_vector(Width - 1 downto 0);
            GrayCounterLookAheadValue : out std_logic_vector(Width - 1 downto 0)
        );
    end component;

    --@ Calculate the log2 of a number
    function log2(N : integer) return integer is
    begin
        if (N <= 2) then
            return 1;
        else
            if (N mod 2 = 0) then
                return 1 + log2(N/2);
            else
                return 1 + log2((N + 1)/2);
            end if;
        end if;
    end function log2;

    --@ FIFO memory address width:
    --@ The address width is calculated from the depth of the FIFO.
    constant AdressWidth : integer := log2(Depth);

    --@ FIFO memory type: `Depth` x `Width`
    type FifoType is array(Depth - 1 downto 0)
    of std_logic_vector(Width - 1 downto 0);
    --@ FIFO memory
    --@ The FIFO memory is implemented as a RAM with the specified `RamTypeFifo`:
    --@ "Block" or "Distributed".
    signal Fifo                 : FifoType;
    attribute RAM_STYLE         : string;
    attribute RAM_STYLE of Fifo : signal is RamTypeFifo;

    --@ Increment enable signal for the read pointer.
    signal ReadCounterEnable : std_logic;
    --@ Internal empty flag; forwarded to the output.
    signal FifoEmpty : std_logic;
    --@ Internal read pointer.
    signal ReadPointer : std_logic_vector(AdressWidth - 1 downto 0);
    --@ Internal read pointer look ahead. (Read pointer + 1)
    signal ReadPointerLookAhead : std_logic_vector(AdressWidth - 1 downto 0);

    --@ Increment enable signal for the write pointer.
    signal WriteCounterEnable : std_logic;
    --@ Internal full flag; forwarded to the output.
    signal FifoFull : std_logic;
    --@ Internal write pointer.
    signal WritePointer : std_logic_vector(AdressWidth - 1 downto 0);
    --@ Internal write pointer look ahead. (Write pointer + 1)
    signal WritePointerLookAhead : std_logic_vector(AdressWidth - 1 downto 0);

begin

    FullFlag  <= FifoFull;
    EmptyFlag <= FifoEmpty;

    --@ Full and empty flags
    --@ 
    --@ The full and empty flags are purely combinatorial calculated
    --@ from a comparison of the read and write pointers/look ahead values.
    Flags : process (WritePointer, ReadPointer, WritePointerLookAhead)
    begin
        if ReadPointer = WritePointerLookAhead then
            FifoFull <= '1';
        else
            FifoFull <= '0';
        end if;
        if ReadPointer = WritePointer then
            FifoEmpty <= '1';
        else
            FifoEmpty <= '0';
        end if;
    end process;

    --@ Write pointer as Gray counter
    --@ 
    --@ The write pointer is incremented by one from the `Write`-process
    --@ if the FIFO is not full and the write enable signal is set.
    --@ The look ahead value is used as the next write pointer value and
    --@ to check if the FIFO is full.
    WriteGrayCounter : GrayCounter
    generic map(
        Width             => AdressWidth,
        InitialValue      => 0,
        ResetValue        => 0,
        CountingDirection => "UP",
        LookAhead         => 1
    )
    port map(
        CLK                       => WriteCLK,
        CE                        => WriteCE,
        RST                       => WriteRST,
        CountEnable               => WriteCounterEnable,
        GrayCounterValue          => WritePointer,
        GrayCounterLookAheadValue => WritePointerLookAhead
    );

    --@ Write process
    --@ 
    --@ The write process writes the data to the FIFO if the FIFO is not full
    --@ and the write enable signal is set.
    --@ `WriteCountEnable` is used to synchronize the write pointer increment
    --@ and is reset every time a rising edge of the write clock is detected.
    Write : process (WriteCLK)
        variable TempW : std_logic_vector(AdressWidth downto 0);
    begin
        if rising_edge(WriteCLK) then
            if WriteRST = '1' then
                WriteCounterEnable <= '0';
            elsif WriteCE = '1' then
                WriteCounterEnable <= '0';

                if WriteEnable = '1' then
                    if FifoFull = '0' then
                        Fifo(to_integer(unsigned(WritePointerLookAhead))) <= DataIn;
                        WriteCounterEnable                                <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    --@ Read pointer as Gray counter
    --@ 
    --@ The read pointer is incremented by one from the `Read`-process
    --@ if the FIFO is not empty and the read enable signal is set.
    --@ 
    --@ The look ahead value is used as the next read pointer value.
    ReadGrayCounter : GrayCounter
    generic map(
        Width             => AdressWidth,
        InitialValue      => 0,
        ResetValue        => 0,
        CountingDirection => "UP",
        LookAhead         => 1
    )
    port map(
        CLK                       => ReadCLK,
        CE                        => ReadCE,
        RST                       => ReadRST,
        CountEnable               => ReadCounterEnable,
        GrayCounterValue          => ReadPointer,
        GrayCounterLookAheadValue => ReadPointerLookAhead
    );

    --@ Read process
    --@ 
    --@ The read process reads the data from the FIFO if the FIFO is not empty
    --@ and the read enable signal is set.
    --@ `ReadCountEnable` is used to synchronize the read pointer increment
    --@ and is reset every time a rising edge of the read clock is detected.
    Read : process (ReadCLK)
        variable TempR : std_logic_vector(AdressWidth downto 0);
    begin
        if rising_edge(ReadCLK) then
            if ReadRST = '1' then
                ReadCounterEnable <= '0';
            elsif ReadCE = '1' then
                ReadCounterEnable <= '0';

                if ReadEnable = '1' then
                    if FifoEmpty = '0' then
                        DataOut           <= Fifo(to_integer(unsigned(ReadPointerLookAhead)));
                        ReadCounterEnable <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
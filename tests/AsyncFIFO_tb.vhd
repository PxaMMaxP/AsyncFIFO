library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AsyncFIFO_tb is
end AsyncFIFO_tb;

architecture behavior of AsyncFIFO_tb is
    component AsyncFIFO
        generic (
            Width       : integer := 32;
            Depth       : integer := 4;
            RamTypeFifo : string  := "Distributed"
        );
        port (
            WriteCLK    : in std_logic;
            WriteRST    : in std_logic;
            WriteCE     : in std_logic;
            DataIn      : in std_logic_vector(31 downto 0);
            WriteEnable : in std_logic;
            FullFlag    : out std_logic;
            ReadCLK     : in std_logic;
            ReadRST     : in std_logic;
            ReadCE      : in std_logic;
            DataOut     : out std_logic_vector(31 downto 0);
            ReadEnable  : in std_logic;
            EmptyFlag   : out std_logic
        );
    end component;

    signal WriteCLK, ReadCLK, WriteRST, ReadRST, WriteCE, ReadCE, WriteEnable, ReadEnable : std_logic                     := '0';
    signal DataIn, DataOut                                                                : std_logic_vector(31 downto 0) := (others => '0');
    signal FullFlag, EmptyFlag                                                            : std_logic;
    constant WriteClkPeriod                                                               : time    := 7 ns;
    constant ReadClkPeriod                                                                : time    := 13 ns;
    constant TotalValues                                                                  : integer := 128; -- Total number of values to write/read
    signal TestEnd                                                                        : boolean := false;
    type TestDataArray is array(0 to 15) of std_logic_vector(31 downto 0);
    constant TestData : TestDataArray := (
    x"AAAAAAAA", x"BBBBBBBB", x"CCCCCCCC", x"DDDDDDDD",
    x"EEEEEEEE", x"FFFFFFFF", x"11111111", x"22222222",
    x"33333333", x"44444444", x"55555555", x"66666666",
    x"77777777", x"88888888", x"99999999", x"AAAAAAAB"
    );

begin
    uut : AsyncFIFO
    generic map(Width => 32, Depth => 16, RamTypeFifo => "Distributed")
    port map(
        WriteCLK => WriteCLK, WriteRST => WriteRST, WriteCE => WriteCE,
        DataIn => DataIn, WriteEnable => WriteEnable, FullFlag => FullFlag,
        ReadCLK => ReadCLK, ReadRST => ReadRST, ReadCE => ReadCE,
        DataOut => DataOut, ReadEnable => ReadEnable, EmptyFlag => EmptyFlag
    );

    WriteClkProcess : process
    begin
        while TestEnd /= true loop
            WriteCLK <= '0';
            wait for WriteClkPeriod/2;
            WriteCLK <= '1';
            wait for WriteClkPeriod/2;
        end loop;
    end process;

    ReadClkProcess : process
    begin
        while TestEnd /= true loop
            ReadCLK <= '0';
            wait for ReadClkPeriod/2;
            ReadCLK <= '1';
            wait for ReadClkPeriod/2;
        end loop;
    end process;

    WriteProcess : process
        variable writeCount : integer := 0; -- Variable für die Anzahl der geschriebenen Werte
    begin
        WriteRST <= '1';
        wait for WriteClkPeriod * 2;
        WriteRST <= '0';
        WriteCE  <= '1';
        while writeCount < TotalValues loop
            wait until rising_edge(WriteCLK);
            if FullFlag = '0' then
                DataIn      <= TestData(writeCount mod 16);
                WriteEnable <= '1';
                wait for WriteClkPeriod;
                WriteEnable <= '0';
                writeCount := writeCount + 1; -- Nur erhöhen, wenn tatsächlich geschrieben wurde
            end if;
        end loop;
        wait;
    end process WriteProcess;

    ReadProcess : process
        variable readCount : integer := 0; -- Variable für die Anzahl der gelesenen Werte
    begin
        ReadRST <= '1';
        wait for ReadClkPeriod * 2;
        ReadRST <= '0';
        ReadCE  <= '1';
        while readCount < TotalValues loop
            wait until rising_edge(ReadCLK);
            if EmptyFlag = '0' then
                ReadEnable <= '1';
                wait for ReadClkPeriod;
                ReadEnable <= '0';
                wait until rising_edge(ReadCLK); -- Warten auf Datenstabilisierung
                -- Assert to check the data correctness
                if DataOut = TestData(readCount mod 16) then
                    report "Data Match!"
                        severity note;
                else
                    assert FALSE
                    report "Data Mismatch. Expected " & integer'image(to_integer(unsigned(TestData(readCount mod 16)))) &
                        " but got " & integer'image(to_integer(unsigned(DataOut)))
                        severity error;
                end if;
                readCount := readCount + 1; -- Nur erhöhen, wenn tatsächlich gelesen wurde
            end if;
        end loop;
        -- Simulation beenden
        TestEnd <= true;
        wait;
    end process ReadProcess;
end behavior;

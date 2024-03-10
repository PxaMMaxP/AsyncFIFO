----------------------------------------------------------------------------------
-- @name        Gray Counter
-- @version     0.0.2
-- @author      Maximilian Passarello (mpassarello.de)
--@             A synchronous Gray counter with reset and enable
-- @history
-- - 0.0.1 (2009-04-02) Initial version
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity GrayCounter is
    generic (
        --@ Width of the counter
        Width : integer := 4;
        --@ Initial value of the counter
        InitialValue : integer := 0;
        --@ Reset value of the counter
        ResetValue : integer := 0;
        --@ Counting direction: "UP" or "DOWN"
        CountingDirection : string := "UP";
        --@ Look ahead value
        LookAhead : integer := 0
    );
    port (
        --@ Clock input; rising edge
        CLK : in std_logic;
        --@ Clock enable; active high
        CE : in std_logic;
        --@ Reset input; active high; synchronous
        RST : in std_logic;
        --@ Count enable; active high
        CountEnable : in std_logic;
        --@ Gray counter value
        GrayCounterValue : out std_logic_vector(Width - 1 downto 0);
        --@ Look ahead value
        GrayCounterLookAheadValue : out std_logic_vector(Width - 1 downto 0)
    );
end GrayCounter;

architecture Behavioral of GrayCounter is
    --@ Convert Binary to Gray code
    function BinaryToGray(BinaryValue : std_logic_vector)
        return std_logic_vector is
        constant Width     : integer := BinaryValue'Length;
        variable GrayValue : std_logic_vector(Width - 1 downto 0);
    begin
        GrayValue(Width - 1) := BinaryValue(Width - 1);
        for i in 1 to Width - 1 loop
            GrayValue((Width - 1) - i) := BinaryValue((Width - 1) - i) xor BinaryValue(((Width - 1) - i) + 1);
        end loop;
        return GrayValue(Width - 1 downto 0);
    end function BinaryToGray;

    --@ Convert Gray code to binary
    function GrayToBinary(GrayValue : std_logic_vector)
        return std_logic_vector is
        constant Width       : integer := GrayValue'Length;
        variable BinaryValue : std_logic_vector(Width - 1 downto 0);
    begin
        BinaryValue(Width - 1) := GrayValue(Width - 1);
        for i in 1 to Width - 1 loop
            BinaryValue((Width - 1) - i) := BinaryValue(Width - i) xor GrayValue((Width - 1) - i);
        end loop;
        return BinaryValue(Width - 1 downto 0);
    end function GrayToBinary;

    function CountingStep(BinaryValue : std_logic_vector; Step : integer := 1)
        return std_logic_vector is
    begin
        if CountingDirection = "DOWN" then
            return std_logic_vector(unsigned(BinaryValue) - Step);
        else
            return std_logic_vector(unsigned(BinaryValue) + Step);
        end if;
    end function CountingStep;

    constant InitialValueVector     : std_logic_vector(Width - 1 downto 0) := std_logic_vector(to_unsigned(InitialValue, Width));
    constant InitialLookAheadVector : std_logic_vector(Width - 1 downto 0) := std_logic_vector(to_unsigned(InitialValue + LookAhead, Width));
    constant ResetValueVector       : std_logic_vector(Width - 1 downto 0) := std_logic_vector(to_unsigned(ResetValue, Width));
    constant ResetLookAheadVector   : std_logic_vector(Width - 1 downto 0) := std_logic_vector(to_unsigned(ResetValue + LookAhead, Width));

    signal BinaryCounter              : std_logic_vector(Width - 1 downto 0) := InitialValueVector;
    signal IntermediateGrayValue      : std_logic_vector(Width - 1 downto 0) := BinaryToGray(InitialValueVector);
    signal IntermediateLookAheadValue : std_logic_vector(Width - 1 downto 0) := BinaryToGray(InitialLookAheadVector);
begin

    GrayCounterValue          <= IntermediateGrayValue;
    GrayCounterLookAheadValue <= IntermediateLookAheadValue;

    Counter : process (CLK)
        variable IntermediateCounter   : std_logic_vector(Width - 1 downto 0);
        variable IntermediateLookAhead : std_logic_vector(Width - 1 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                IntermediateCounter := (others => '0');
                IntermediateGrayValue      <= BinaryToGray(ResetValueVector);
                IntermediateLookAheadValue <= BinaryToGray(ResetLookAheadVector);
                BinaryCounter              <= ResetValueVector;
            elsif CE = '1' then
                if CountEnable = '1' then
                    IntermediateCounter := CountingStep(BinaryCounter);
                    BinaryCounter         <= IntermediateCounter;
                    IntermediateGrayValue <= BinaryToGray(IntermediateCounter);
                    IntermediateLookAhead := CountingStep(IntermediateCounter, LookAhead);
                    IntermediateLookAheadValue <= BinaryToGray(IntermediateLookAhead);
                end if;
            end if;
        end if;
    end process;
end Behavioral;

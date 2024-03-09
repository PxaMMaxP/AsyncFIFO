----------------------------------------------------------------------------------
-- @Name 	GrayCounter
-- @Version	0.0.1
-- @Author	Maximilian Passarello
-- @E-Mail	atom-dragon@gmx.net
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity GrayCounter is
    generic (Width : integer := 4);
    port (
        CLK         : in std_logic;
        CE          : in std_logic;
        RST         : in std_logic;
        CountEnable : in std_logic;
        Dout        : out std_logic_vector(Width - 1 downto 0));
end GrayCounter;

architecture Behavioral of GrayCounter is
    signal BinaryCount : std_logic_vector(Width - 1 downto 0);
begin
    process (CLK)
        variable Gray        : std_logic_vector(Width - 1 downto 0);
        variable TempCounter : std_logic_vector(Width - 1 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                Gray        := (others => '0');
                TempCounter := (others => '0');
                BinaryCount <= (others => '0');
                Dout        <= (others => '0');
            elsif CE = '1' then
                if CountEnable = '1' then
                    TempCounter := std_logic_vector(unsigned(BinaryCount) + 1);
                    BinaryCount <= TempCounter;
                    Gray(Width - 1) := TempCounter(Width - 1);
                    for i in 1 to Width - 1 loop
                        Gray((Width - 1) - i) := TempCounter((Width - 1) - i) xor TempCounter(((Width - 1) - i) + 1);
                    end loop;
                    Dout <= Gray;
                end if;
            end if;
        end if;
    end process;
end Behavioral;

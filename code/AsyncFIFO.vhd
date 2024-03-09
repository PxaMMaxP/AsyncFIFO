----------------------------------------------------------------------------------
-- @Name 	FIFO2CLK
-- @Version	1.1.0
-- @Author	Maximilian Passarello
-- @E-Mail	atom-dragon@gmx.net
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity FIFO2CLK is
    generic (
        Width       : integer := 32;             --Wort Breite
        Depth       : integer := 4;              --FIFO Adress Breite
        RamTypeFifo : string  := "Distributed"); --Ram Typ des Fifos | Block or Distributed |
    port (
        CLKwrite : in std_logic;
        CLKread  : in std_logic;
        --CE : In std_logic;
        RST   : in std_logic;
        Din   : in std_logic_vector(Width - 1 downto 0);
        Dout  : out std_logic_vector(Width - 1 downto 0);
        RE    : in std_logic;
        WE    : in std_logic;
        Empty : out std_logic;
        Full  : out std_logic);
end FIFO2CLK;

--	component FIFO2CLK
--		generic(	Width : integer := 32;
--					Depth : integer := 32;
--					RamTypeFifo : string := "Distributed");
--		port(	CLKwrite : In std_logic;
--				CLKread : In std_logic;
--				--CE : In std_logic;
--				RST : In std_logic;
--				Din : In std_logic_vector(Width-1 downto 0);
--				Dout : Out std_logic_vector(Width-1 downto 0);
--				RE : In std_logic;
--				WE : In std_logic;
--				Empty : Out std_logic;
--				Full : Out std_logic);
--	end component;
--
--	FIFO2CLK0: FIFO2CLK
--		generic map(Width => 32,
--						Depth => 32,
--						RamTypeFifo => "Distributed")
--		port map(CLKwrite => ,
--					CLKread => ,
--					--CE => ,
--					RST => ,
--					Din => ,
--					Dout => ,
--					RE => ,
--					WE => ,
--					Empty => ,
--					Full => );

architecture Behavioral of FIFO2CLK is

    signal CE : std_logic := '1';

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

    function GrayToBinary(Bin : std_logic_vector) return std_logic_vector is
        constant Width            : integer := Bin'Length;
        variable Temp             : std_logic_vector(Width - 1 downto 0);
    begin
        Temp(Width - 1) := Bin(Width - 1);
        for i in 1 to Width - 1 loop
            Temp((Width - 1) - i) := Temp(Width - i) xor Bin((Width - 1) - i);
        end loop;
        return Temp(Width - 1 downto 0);
    end function GrayToBinary;

    --	function BinaryToGray(Bin : std_logic_vector) return std_logic_vector is
    --		constant Width : integer := Bin'Length;
    --		variable Temp : std_logic_vector(Width downto 0);
    --	begin
    --		Temp := std_logic_vector(unsigned('0' & (Bin));
    --		Temp := (Temp(Width-1 downto 0) & '0') XOR ('0' & Temp(Width-1 downto 0));
    --		Temp := '0' & Temp(Width downto 1);
    --		Temp := '0' & Temp(Width-1 downto 0);
    --		return Temp(Width-1 downto 0);
    --	end function BinaryToGray;

    constant AdressWidth : integer := log2(Depth);

    attribute RAM_STYLE : string;

    type FifoType is array(Depth - 1 downto 0)
    of std_logic_vector(Width - 1 downto 0);
    signal Fifo : FifoType;

    attribute RAM_STYLE of Fifo : signal is RamTypeFifo;

    signal RCount    : std_logic_vector(AdressWidth - 1 downto 0);
    signal RCountBB  : std_logic_vector(AdressWidth - 1 downto 0);
    signal RCountOut : std_logic_vector(AdressWidth - 1 downto 0);
    signal RCountIn0 : std_logic_vector(AdressWidth - 1 downto 0);
    signal RCountIn1 : std_logic_vector(AdressWidth - 1 downto 0);
    signal WCount    : std_logic_vector(AdressWidth - 1 downto 0);
    signal WCountBB  : std_logic_vector(AdressWidth - 1 downto 0);
    signal WCountOut : std_logic_vector(AdressWidth - 1 downto 0);
    signal WCountIn0 : std_logic_vector(AdressWidth - 1 downto 0);
    signal WCountIn1 : std_logic_vector(AdressWidth - 1 downto 0);

    signal FifoFull  : std_logic;
    signal FifoEmpty : std_logic;

begin

    Full  <= FifoFull;
    Empty <= FifoEmpty;

    process (CLKwrite)
        variable TempW : std_logic_vector(AdressWidth downto 0);
    begin
        if rising_edge(CLKwrite) then
            if RST = '1' then
                WCount    <= (others => '0');
                WCountOut <= (others => '0');
                RCountIn0 <= (others => '0');
                RCountIn1 <= (others => '0');
                FifoFull  <= '0';
            elsif CE = '1' then
                RCountIn0 <= RCountOut;
                RCountIn1 <= RCountIn0;
                RCountBB  <= GrayToBinary(RCountIn1);
                if GrayToBinary(RCountIn1) = std_logic_vector(unsigned(WCount) + 1) then
                    FifoFull <= '1';
                else
                    FifoFull <= '0';
                end if;
                if WE = '1' then
                    if GrayToBinary(RCountIn1) /= std_logic_vector(unsigned(WCount) + 1) then
                        TempW := std_logic_vector(unsigned('0' & WCount) + 1);
                        TempW := (TempW(AdressWidth - 1 downto 0) & '0') xor ('0' & TempW(AdressWidth - 1 downto 0));
                        TempW := '0' & TempW(AdressWidth downto 1);
                        TempW := '0' & TempW(AdressWidth - 1 downto 0);
                        WCountOut                              <= TempW(AdressWidth - 1 downto 0);
                        WCount                                 <= std_logic_vector(unsigned(WCount) + 1);
                        Fifo(to_integer(unsigned(WCount) + 1)) <= Din;
                    end if;
                end if;
            end if;
        end if;
    end process;

    process (CLKread)
        variable TempR : std_logic_vector(AdressWidth downto 0);
    begin
        if rising_edge(CLKread) then
            if RST = '1' then
                RCount    <= (others => '0');
                RCountOut <= (others => '0');
                WCountIn0 <= (others => '0');
                WCountIn1 <= (others => '0');
                Dout      <= (others => '0');
                FifoEmpty <= '1';
            elsif CE = '1' then
                WCountIn0 <= WCountOut;
                WCountIn1 <= WCountIn0;
                WCountBB  <= GrayToBinary(WCountIn1);
                if GrayToBinary(WCountIn1) = RCount then
                    FifoEmpty <= '1';
                else
                    FifoEmpty <= '0';
                end if;
                if RE = '1' then
                    if GrayToBinary(WCountIn1) /= RCount then
                        TempR := std_logic_vector(unsigned('0' & RCount) + 1);
                        TempR := (TempR(AdressWidth - 1 downto 0) & '0') xor ('0' & TempR(AdressWidth - 1 downto 0));
                        TempR := '0' & TempR(AdressWidth downto 1);
                        TempR := '0' & TempR(AdressWidth - 1 downto 0);
                        RCountOut <= TempR(AdressWidth - 1 downto 0);
                        RCount    <= std_logic_vector(unsigned(RCount) + 1);
                        Dout      <= Fifo(to_integer(unsigned(RCount) + 1));
                    else
                        Dout <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
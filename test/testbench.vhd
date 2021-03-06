library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.constants.all;

entity testbench is
end entity testbench;

architecture RTL of testbench is
	component cpu_top is
		port(
			I_CLK : in  std_logic;
			I_RST : in  std_logic;
			I_DAT : in  std_logic_vector(XLEN - 1 downto 0);
			Q_ADR : out std_logic_vector(XLEN - 1 downto 0);
			Q_DAT : out std_logic_vector(XLEN - 1 downto 0);
			Q_RW  : out std_logic
		);
	end component cpu_top;

	signal C_RW   : std_logic;
	signal C_ADR  : std_logic_vector(XLEN - 1 downto 0);
	signal C_DATO : std_logic_vector(XLEN - 1 downto 0);
	signal C_DATI : std_logic_vector(XLEN - 1 downto 0);

	component ram is
		generic(
			ADR_BITS : natural := 7;
			DATA_LEN : natural := 8
		);
		port(
			I_CLK : in  std_logic;
			I_RW  : in  std_logic;
			I_ADR : in  std_logic_vector(ADR_BITS - 1 downto 0);
			I_DAT : in  std_logic_vector(DATA_LEN - 1 downto 0);
			Q_DAT : out std_logic_vector(DATA_LEN - 1 downto 0)
		);
	end component ram;

	signal A_RW  : std_logic;
	signal A_DAT : std_logic_vector(XLEN - 1 downto 0);

	component rom is
		generic(
			DATA_FILE : string;
			ADR_BITS : natural := 6;
			DATA_LEN : natural := 8
		);
		port(
			I_CLK : in  std_logic;
			I_ADR : in  std_logic_vector(ADR_BITS - 1 downto 0);
			Q_DAT : out std_logic_vector(DATA_LEN - 1 downto 0)
		);
	end component rom;

	signal O_DAT : std_logic_vector(XLEN - 1 downto 0);

	component tty is
		port(
			I_CLK : in std_logic;
			I_W   : in std_logic;
			I_DAT : in std_logic_vector(XLEN - 1 downto 0)
		);
	end component tty;

	signal T_W : std_logic;

	signal L_CLK : std_logic := '0';
	signal L_RST : std_logic := '1';
begin
	clock : process
	begin
		L_CLK <= transport '1';
		wait for CLOCK_PERIOD / 2;

		L_CLK <= transport '0';
		wait for CLOCK_PERIOD / 2;

		if (L_RST = '1') then
			L_RST <= '0';               -- The RST signal is enabled for one clock cycle
		end if;
	end process clock;

	cpu_mod : cpu_top
		port map(
			I_CLK => L_CLK,
			I_RST => L_RST,
			I_DAT => C_DATI,
			Q_ADR => C_ADR,
			Q_DAT => C_DATO,
			Q_RW  => C_RW
		);

	ram_mod : ram
		generic map(
			ADR_BITS => RAM_BITS,
			DATA_LEN => XLEN
		)
		port map(
			I_CLK => L_CLK,
			I_RW  => A_RW,
			I_ADR => C_ADR(RAM_BITS - 1 downto 0),
			I_DAT => C_DATO,
			Q_DAT => A_DAT
		);

	rom_mod : rom
		generic map(
			DATA_FILE => "rom_helloworld.txt",      -- Load ROM data
			ADR_BITS => ROM_BITS,
			DATA_LEN => XLEN
		)
		port map(
			I_CLK => L_CLK,
			I_ADR => C_ADR(ROM_BITS - 1 downto 0),
			Q_DAT => O_DAT
		);

	tty_mod : tty
		port map(
			I_CLK => L_CLK,
			I_W   => T_W,
			I_DAT => C_DATO
		);

		-- Select input data based on address range
	C_DATI <= A_DAT when (C_ADR(7) = '0') -- RAM
		else O_DAT when (C_ADR(7 downto 6) = "11") -- ROM
		else (others => '0');           -- IO

	-- Write TTY when the address is TTY_ADDR
	T_W <= '1' when C_ADR(7 downto 0) = TTY_ADDR and C_RW = '1' else '0';
	
	-- Read/Write RAM when the address is within the 0xxxxxxx range (0x00 - 0x7f)
	A_RW <= C_RW when (C_ADR(7) = '0') else '0';
end architecture RTL;

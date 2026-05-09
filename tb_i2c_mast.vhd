library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_i2c_mast is
end entity tb_i2c_mast;


architecture sim of tb_i2c_mast is
	-- DUT Signals
	signal clk: std_logic := '0';
	signal rst: std_logic := '0';

	signal sda: std_logic := 'Z';
	signal scl: std_logic := 'Z';

	signal start_flag: std_logic := '0';
	signal address_in: std_logic_vector(6 downto 0) := "1001111";
	signal data_in: std_logic_vector(7 downto 0) := x"DE";
	signal transaction_t_in: std_logic := '0';

	-- Sim signals
	constant T: time := 10 ns;
	signal simDone: std_logic := '0';
begin
	dut: entity work.i2c_master 
		port map (
			clk=>clk,
			rst=>rst,
			sda=>sda,
			scl=>scl,
			start_flag=>start_flag,
			address_in=>address_in,
			data_in=>data_in,
			transaction_t_in=>transaction_t_in
		);

	clk_proc: process
	begin
		while simDone='0' loop
			clk <= not clk;
			wait for T/2;
		end loop;
		wait;
	end process clk_proc;

	stim_proc: process 
	begin
		wait for T * 5000;
		start_flag <= '1';
		wait until falling_edge(clk);
		start_flag <= '0';
		wait for T * 20000;
		simDone<='1';
		wait;
	end process stim_proc;

end architecture sim;

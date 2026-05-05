library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity i2c_master is
	port (
		-- Normal ports
		clk: in std_logic;
		rst: in std_logic;

		-- i2c ports
		sda: inout std_logic;
		scl: out std_logic;

		-- Module control
		-- Maybe add done flag
		start_flag: in std_logic;
		address_in: in std_logic_vector(6 downto 0);
		data_in: in std_logic_vector(7 downto 0);
		transaction_type_in: in std_logic 
	);
end entity i2c_master;


-- Note that normal mode is 100kbps
architecture A1 of i2c_master is
	-- States
	type i2c_state is (idle, start_sda, start_scl, address, rw, a_ack, data, d_ack);
	signal p_state, n_state: i2c_state := idle;

	-- Registers for control data
	signal address_reg: std_logic_vector(6 downto 0) := (others => '0');
	signal data_reg: std_logic_vector(7 downto 0) := (others => '0');
	signal rw_reg: std_logic := '0'; 	

	-- Control of tri state buffer for SDA
	signal sda_out_ctrl: std_logic := '1';
	signal sda_drive: std_logic := '1';
begin
	-- Tri state buffer, output is data we want to drive when 
	sda <= sda_drive when sda_out_ctrl='1' else 'Z';

	register_data: process (clk) 
	begin
		if rising_edge(clk) then
			if rst='1' then
				address_reg <= (others => '0');
				data_reg <= (others => '0');
				rw_reg <= (others => '0');
			else
				if start_flag='1' then
					address_reg <= address_in;
					data_reg <= data_in;
					rw_reg <= transation_type_in;
				end if;
			end if;
		end if;
	end process register_data;

	seq_state_proc: process(clk)
	begin
		if rising_edge(clk) then
			if rst='1' then
				p_state <= idle;
			else
				p_state <= n_state;	
			end if;
		end if;
	end process state_proc;		

	comb_proc: process(p_state, start_flag)
	begin
		case p_state is
			when idle =>
				if start_flag='1' then
					n_state <= start_sda;
				else
					n_state <= idle;
				end if;		
			when start_sda =>
				
			when start_scl =>

			when address =>

			when rw =>

			when a_ack =>

			when data =>

			when d_ack =>

			when others =>
				NULL;
		end case;	
	end process comb_proc;

end architecture A1;

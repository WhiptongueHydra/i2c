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
	-- State stuff
	type i2c_state is (idle, sda_low, scl_low, address, transaction_type, ack_a, data, data_a)
	signal current_state: i2c_state := idle;

	-- Buf controls
	signal sda_ctrl, scl_strl: std_logic := '0';
begin
	sda <= '0' when sda_ctrl='1' else 'Z';
	scl <= '0' when scl_ctrl='1' else 'Z';

	i2c_proc: process(clk) 
	begin
		if rising_edge(clk) then
			if rst='1' then
				current_state <= idle;
				sda_ctrl <= '0';
				scl_ctrl <= '0';	
			else
				current_state <= idle;
				case current_state is
					when idle =>
						sda_ctrl <= '0';
						scl_crtl <= '0';
						if start_flag='1' then
							current_state <= sda_low;
							sda_ctrl <= '1';
							-- Start counter signal=1 below
						end if;

					when sda_low =>
						sda_ctrl <= '0';
						-- If start counter signal=1 and count < 3 or something keep incrementing. If not move to SCL low:

					when scl_low =>



					when others =>
						NULL;
				end case;
			end if;
		end if;	
	end process i2c_proc;
end architecture A1;

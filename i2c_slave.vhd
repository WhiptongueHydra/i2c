library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity i2c_slave is
	port (
		clk: in std_logic;
		rst: in std_logic;

		sda: inout std_logic;
		scl: in std_logic
	);
end entity i2c_slave;


architecture A1 of i2c_slave is
	constant slave_addr: std_logic_vector(7 downto 0) := x"50";
	signal slave_data_reg: std_logic_vector(7 downto 0) := x"DE";

	type i2c_slv_state is (idle, receiving_a, ack_a, receiving_d, ack_d);
	signal last_state, current_state: i2c_slv_state;

	signal sda_ctrl: std_logic := '1';


	-- 	Edge detection
	signal prev_scl: std_logic := '1';
	signal edge_rise: std_logic := '0';
	signal edge_fall: std_logic := '0';

	-- 	I2C Ctrl Signals
	-- Number of bytes - 1
	constant max_byte_index: integer := 8;
	signal byte_count: integer range 0 to 8 := 8; -- Seemed wasteful of the extra 1 bit 
	signal addr_reg: std_logic_vector(7 downto 0);
	-- 0: write
	-- 1: read
	signal transaction_type: std_logic := '1';

	-- Ack ctrl 
	signal scl_low_detected: std_logic := '0';
begin
	sda <= 'Z' when sda_ctrl='1' else '0';

	scl_edge_det: process(clk) 
	begin
		if rising_edge(clk) then
			if rst='1' then
				prev_scl <= '1';
			else	
				prev_scl <= scl;
				if scl='1' and prev_scl='0' then
					edge_rise <= '1';
				else
					edge_rise <= '0';
				end if;

				if scl='0' and prev_scl='1' then
					edge_fall <= '1';
				else
					edge_fall <= '0';
				end if;
			end if;
		end if;
	end process scl_edge_det;

	i2c_fsm_proc: process(clk)
	begin
		if rising_edge(clk) then
			if rst='1' then
				current_state <= idle;
			else
				last_state <= current_state;
				case current_state is
					when idle =>
						current_state <= idle;
						sda_int <= '1';
						if scl='1' and sda='0' then
							current_state <= receiving_a;
						end if;					

					when receiving_a =>
						current_state <= receiving_a;
						if edge_rising='1' then
							if byte_count < 8 then
								addr_reg(byte_count) <= sda;
								byte_count <= byte_count + 1;	
							else
								transaction_type <= sda;
								byte_count <= 0;
								if addr_reg=slave_reg then
									current_state <= wait_scl_low;
								else
									current_state <= idle;
								end if;
							end if;
						end if;

					-- This is so scuffed but it should work
					when ack_a =>
						current_state <= ack_a;
						-- Pull low after SCL falling edge, keep low until next falling edge then deassert
						if edge_fall='1' and scl_low_detected='0' then
							scl_ctrl <= '0';
							scl_low_detected <= '1';
						elsif edge_fall='1' and scl_low_detected='1' then
							scl_ctrl <= '1';
							scl_low_detected <= '0';
							current_state <= trans_type; 
						else
							scl_ctrl <= scl_ctrl;
							scl_low_detected <= scl_low_detected;
						end if;


					when trans_type =>
						-- Read
						if transaction_type='1' then 
							current_state <= read_out;	

						-- Write
						else
							current_state <= write_in;

						end if;			

					when read_out =>
						current_state <= receiving_a;
						if edge_rising='1' then
							if byte_count < 8 then
								addr_reg(byte_count) <= sda;
								byte_count <= byte_count + 1;	
							else
								transaction_type <= sda;
								byte_count <= 0;
								if addr_reg=slave_reg then
									current_state <= wait_scl_low;
								else
									current_state <= idle;
								end if;
							end if;
						end if;


					when write_in =>


					when others =>
						NULL;
				end case;
			end if;
		end if;
	end process i2c_fsm_proc;	
end architecture A1;

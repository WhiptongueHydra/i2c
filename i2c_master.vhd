library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 100MHz clock
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
		-- Might add a num_bytes input from a fifo or something
		-- Can run til the fifo is empty
		data_in: in std_logic_vector(7 downto 0);
		transaction_t_in: in std_logic;

		fail: out std_logic	
	);
end entity i2c_master;


-- Note that normal mode is 100kbps
architecture A1 of i2c_master is
	-- State stuff
	type i2c_state is (idle, start_con, address, transaction_type, ack_a, wait_a, data, ack_d, wait_d, stop_con);
	signal current_state: i2c_state := idle;

	-- Buf controls
	signal sda_ctrl, scl_ctrl: std_logic := '1';

	-- Counter controls
	signal counter_en: std_logic := '0';
	signal counter: integer range 0 to 1000 := 0;
	constant max_count: integer := 999;
	constant half_count: integer := 449;
	constant q_count: integer := 749;
	signal max_reached: std_logic := '0';
	signal half_reached: std_logic := '0';
	signal q_reached: std_logic := '0';


	-- Internal registers
	signal address_reg: std_logic_vector(6 downto 0);
	signal data_reg: std_logic_vector(7 downto 0);
	signal transaction_t_reg: std_logic; 

	-- Index ctrl
	signal address_index: integer range 0 to 6 := 6;
	signal data_index: integer range 0 to 7 := 7;
	
	-- Ack ctrl
	signal fail_int: std_logic := '0';

	-- Wait ctrl
	signal wait_a_flag: std_logic := '0';
	signal wait_d_flag: std_logic := '0';


begin
	sda <= '0' when sda_ctrl='0' else 'Z';
	scl <= '0' when scl_ctrl='0' else 'Z';

	fail <= '1' when fail_int='1' else '0';

	-- Need single pulsar for start_en
	latch_data: process(clk) 
	begin
		if rising_edge(clk) then
			if rst='1' then
				address_reg <= (others => '1');
				data_reg <= (others => '1');
				transaction_t_reg <= '1';
			else
				if start_flag='1' then
					address_reg <= address_in;
					data_reg <= data_in;
					transaction_t_reg <= transaction_t_in;				
				end if;
			 end if;	
		end if;
	end process latch_data;

	counter_proc: process(clk) 
	begin
		if rising_edge(clk) then
			if rst='1' then
				max_reached <= '0';
				half_reached <= '0';
				q_reached <= '0';
				counter <= 0;
			else
				max_reached <= '0';
				half_reached <= '0';
				q_reached <= '0';
				if counter_en='1' then
					counter <= counter + 1;
					if counter >= half_count-1 then
						half_reached <= '1';
					end if;
					
					if counter >= q_count-1 then
						q_reached <= '1';
					end if;

					if counter = max_count-1 then
						half_reached <= '0';
						q_reached <= '0';
						max_reached <= '1';
						counter <= 0;
					end if;
				else
					counter<=0;
					max_reached <= '0';
					half_reached <= '0';
				end if;
			end if;
		end if;	
	end process counter_proc;

	i2c_proc: process(clk) 
	begin
		if rising_edge(clk) then
			if rst='1' then
				current_state <= idle;
				address_index <= 6;
				sda_ctrl <= '1';
				scl_ctrl <= '1';
				fail_int <= '1';
				counter_en <= '0';	
			else
				current_state <= idle;
				case current_state is
					when idle =>
						counter_en <= '0';
						sda_ctrl <= '1';
						scl_ctrl <= '1';
						if start_flag='1' then
							current_state <= start_con;
							sda_ctrl <= '0';
							-- Start counter signal=1 below
							counter_en <= '1';
						end if;

					when start_con =>
						fail_int <= '0';
						sda_ctrl <= '0';
						counter_en <= '1';
						if max_reached='1' then
							scl_ctrl <= '0';
							current_state <= address;
						else
							current_state <= start_con;
						end if;	
					
					when address  =>
						-- Scl low, drive address bit onto bus
						counter_en <= '1';
						current_state <= address;

						if address_reg(address_index)='1' then
							sda_ctrl <= '1';
						else
							sda_ctrl <= '0';
						end if;	

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;

						if max_reached='1' then
							if address_index = 0 then
								address_index <= 6;
								scl_ctrl <= '0';
								current_state <= transaction_type;
							else
								scl_ctrl <= '0';
								address_index <= address_index-1;	
							end if;
						end if;

					when transaction_type =>
						counter_en <= '1';

						if transaction_t_reg='1' then
							sda_ctrl <= '1';
						else
							sda_ctrl <= '0';
						end if;

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;		

						if max_reached='1' then
							sda_ctrl <= '1';	
							current_state <= ack_a;
						else 
							current_state <= transaction_type;
						end if;

					when ack_a =>
						counter_en <= '1';
						sda_ctrl <= '1';
						current_state <= ack_a;

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;		
						

						if q_reached='1' then
							if sda='0' then	
								current_state <= wait_d;
							else
								fail_int <= '1';
								current_state <= stop_con;
							end if;	
						end if;

					when wait_a =>
						counter_en <= '1';
						current_state <= wait_a;

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;		
						

						if wait_a_flag='1' then
							scl_ctrl <= '0';
							if max_reached='1' then
								current_state <= data;
							end if;
						else
							if max_reached='1' then
								scl_ctrl <= '0';
								wait_a_flag <= '1';
							end if;
						end if;
				
					when data =>
						-- Scl low, drive address bit onto bus
						counter_en <= '1';
						current_state <= data;

						if data_reg(data_index)='1' then
							sda_ctrl <= '1';
						else
							sda_ctrl <= '0';
						end if;	

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;

						if max_reached='1' then
							if data_index = 0 then
								data_index <= 7;
								scl_ctrl <= '0';
								current_state <= ack_d;
							else
								scl_ctrl <= '0';
								data_index <= data_index-1;	
							end if;
						end if;

					when ack_d =>
						counter_en <= '1';
						sda_ctrl <= '1';
						current_state <= ack_d;

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;		
						

						if q_reached='1' then
							if sda='0' then	
								current_state <= wait_d;
							else
								fail_int <= '1';
								current_state <= stop_con;
							end if;	
						end if;

					when wait_d =>
						counter_en <= '1';
						current_state <= wait_d;

						if half_reached='1' then
							scl_ctrl <= '1';
						else
							scl_ctrl <= '0';
						end if;		
						

						if wait_d_flag='1' then
							scl_ctrl <= '0';
							if max_reached='1' then
								scl_ctrl <= '1';
								current_state <= stop_con;
							end if;
						else
							if max_reached='1' then
								scl_ctrl <= '0';
								wait_d_flag <= '1';
							end if;
						end if;


					when stop_con =>
						current_state <= stop_con;
						counter_en <= '1';
						scl_ctrl <= '1';
						
						if max_reached='1' then
							counter_en <= '0';
							sda_ctrl <= '1';
							current_state <= idle;
						else
							sda_ctrl <= '0';
						end if;	
					
					when others =>
						NULL;
				end case;
			end if;
		end if;	
	end process i2c_proc;
end architecture A1;

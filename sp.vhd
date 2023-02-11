library ieee;
use ieee.std_logic_1164.all;
entity sp is
		generic(
			G_N               : integer:= 16 );
		port (
			i_clk                          : in  std_logic;
			i_rstb                         : in  std_logic;
			i_data_ena                     : in  std_logic;
			i_data                         : in  std_logic;
			o_data_valid                   : out std_logic;
			o_data                         : out std_logic_vector(G_N-1 downto 0)
		);
end sp;

architecture behav of sp is
	signal r_data_enable                  : std_logic;
	signal r_data                         : std_logic_vector(G_N-1 downto 0);
	signal r_count                        : integer range 0 to G_N-1;
	begin
		serial2parallel : process(i_clk,i_rstb)
		begin
			if(i_rstb = '0') then
				r_data_enable        <= '0';
				r_count              <= 0;
				r_data               <= (others=>'0');
				o_data_valid         <= '0';
				o_data               <= (others=>'0');
			elsif(rising_edge(i_clk)) then
				o_data_valid         <= r_data_enable;
			
				if(r_data_enable='1') then
					o_data         <= r_data;
				end if;
			
				if(i_data_ena='1') then
					r_data         <= r_data(G_N-2 downto 0)&i_data;
					if(r_count >= G_N-1) then
						r_count        <= 0;
						r_data_enable  <= '1';
					else
						r_count        <= r_count + 1;
						r_data_enable  <= '0';
					end if;
				else
					r_data_enable  <= '0';
				end if;
		  end if;
	end process serial2parallel;
end architecture;
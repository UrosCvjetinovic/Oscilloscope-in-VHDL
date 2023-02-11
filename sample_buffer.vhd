library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity sample_buffer is port (
				reset : in std_logic;		-- asinhron
				enable	: in std_logic;	--
				clk_65mhz : in std_logic;	-- 65Mhz
				sample_c	: in std_logic;	-- 80.64khz
				rd_wr		: in std_logic;	-- '1' upis, '0' ispis
				i_data	: in std_logic_vector(11 downto 0);
				
				wr_element : in integer range 0 to 1343;
				o_data : out std_logic_vector(11 downto 0)
); 
end entity;


architecture buffer_behav of sample_buffer is 

 type array_std_vector is array (0 to 1343) of std_logic_vector(11 downto 0);
 signal buffer_arr	: array_std_vector;


signal rd_addr	 : integer range 0 to 1343;
signal wr_addr	 : integer range 0 to 1343;

begin
		wr_addr <= wr_element;
		
		--Proces koji upisuje na 80.64kHz a ispisuje na 65mhz		
		process (enable,sample_c,reset,rd_wr,clk_65mhz)
		begin
			if (reset ='1' or enable = '0') then
					rd_addr <= 0;
			elsif (rd_wr = '1') then
					if (rising_edge(sample_c)) then		-- Ucitavanje
						if (rd_addr < 1344) then 
							buffer_arr(rd_addr) <= i_data; --radi na 80640Hz
							rd_addr <= rd_addr + 1;
						else
							rd_addr <= 0;
						end if;
					end if;
				else 								
					if (rising_edge(clk_65mhz)) then			-- Ispisivanje
						o_data <= buffer_arr(wr_addr); --
				end if;
			end if;		
		end process;

end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oscilloscope is
		port (
			reset			:	in	std_logic;
			i_dout		: 	in std_logic;		--Dout
			clk_50mhz	: in std_logic;
			
			sclk		: out std_logic;	
			cs 		: out std_logic;			
			o_din 	: out std_logic;  --Din
			
			VGA_CLK 							:out std_logic;
			VGA_HS, VGA_VS, VGA_SYNC_N, VGA_BLANK_N :out std_logic;
			VGA_R, VGA_G, VGA_B 			:out std_logic_vector(7 downto 0)
			
		);
end oscilloscope;

architecture struct of oscilloscope is

	--Pretvarac paralelnog u serijski
	component ps is
		generic(
			G_N               : integer:= 16 );
		port (
		  i_clk                          : in  std_logic;
		  i_rstb                         : in  std_logic;
		  i_data_ena                     : in  std_logic;
		  i_data                         : in  std_logic_vector(G_N-1 downto 0);
		  o_data_valid                   : out std_logic;
		  o_data                         : out std_logic
		  );
	end component;
	
	--Pretvarac serijskog u paralelni
	component sp is
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
	end component;
	
	--Kontroler
	component adccontroler is
		generic(
			N_clk          : integer:= 31 
		);
		port (
			reset				:	in	 std_logic;
			sclk				:	in  std_logic;
			o_data_ena_ps	:	out std_logic;
			o_data_ena_sp	:	out std_logic;
			o_cs				:	out std_logic;								--Aktivan na nuli
			o_din				:	out std_logic_vector(15 downto 0);
			sample_clk		:	out std_logic;
			sample			:	out std_logic
			
		);
	end component;
	
	--Bafer
	component sample_buffer is port (
				reset 		: in std_logic;		-- asinhron
				enable		: in std_logic;	--
				clk_65mhz 	: in std_logic;	-- 65Mhz
				sample_c		: in std_logic;	-- 80.64khz
				rd_wr			: in std_logic;	-- '1' upis, '0' ispis
				i_data		: in std_logic_vector(11 downto 0);
				wr_element : in integer range 0 to 1343;
				
				o_data 		: out std_logic_vector(11 downto 0)
	
	); 
	end component;
	
	--PLL 
	component pll_65 is	
		port (
			refclk   : in  std_logic := '0'; --  refclk.clk
			rst      : in  std_logic := '0'; --   reset.reset
			outclk_0 : out std_logic        -- outclk0.clk
		);
	end component;
	
	component vga_sync is
		generic (
			-- Default display mode is 1024x768@60Hz
			-- Horizontal line
			H_SYNC	: integer := 136;		-- sync pulse in pixels
			H_BP		: integer := 160;		-- back porch in pixels
			H_FP		: integer := 24;		-- front porch in pixels
			H_DISPLAY: integer := 1024;	-- visible pixels
			-- Vertical line
			V_SYNC	: integer := 6;		-- sync pulse in pixels
			V_BP		: integer := 29;		-- back porch in pixels
			V_FP		: integer := 3;		-- front porch in pixels
			V_DISPLAY: integer := 768		-- visible pixels
		);
		port (
			clk : in std_logic;
			reset : in std_logic;
			hsync, vsync : out std_logic;
			sync_n, blank_n : out std_logic;
			hpos : out integer range 0 to H_DISPLAY - 1;
			vpos : out integer range 0 to V_DISPLAY - 1;
			Rin, Gin, Bin : in std_logic_vector(7 downto 0);
			Rout, Gout, Bout : out std_logic_vector(7 downto 0)
		);
	end component;

	signal data_ena_ps 		: std_logic;
	signal data_ena_sp 		: std_logic;
	
	signal data_ps 			: std_logic;
	signal data_sp 			: std_logic_vector(15 downto 0);
	signal data_valid_ps 	: std_logic;
	signal data_valid_sp 	: std_logic;
	signal r_rtsb 				: std_logic;
	signal r_dout				: std_logic;
	signal r_din				: std_logic_vector(15 downto 0);
	signal r_sample_clk		: std_logic;    			--80.64kHz
	signal r_sample 			: std_logic;
	
	signal r_sclk			: std_logic;
	signal data_buffer1 	: std_logic_vector(11 downto 0);
	signal data_buffer2 	: std_logic_vector(11 downto 0);
	signal data_buffer 	: std_logic_vector(11 downto 0);
	signal rd_wr			: std_logic:= '0';
	signal rd_wr_n			: std_logic:= '0';
	
	signal cnt_60hz		: integer range 0 to 678;
	signal clk_60hz		: std_logic := '0';
	signal cnt_sclk		: integer range 0 to 14;
	
	signal clk_vga 			: std_logic;							--65 Mhz
	signal Rval, Gval, Bval : std_logic_vector(7 downto 0);
	signal hpos 				: integer range 0 to 1023;
	signal vpos 				: integer range 0 to 767;
	signal H_DISPLAY			: integer := 1024;	-- vidljivi deo ekrana
	signal V_DISPLAY			: integer := 768;
	
	begin

		r_rtsb 		<= not reset;
		r_dout		<= i_dout;
		o_din			<= data_ps;
		sclk			<= r_sclk;
		
		
		--Proces koji kreira 31*80640hz od 65Mhz
		process (clk_vga,reset,r_sample)	is
		begin
			if (reset='1') then
				r_sclk <= '0';
				cnt_sclk <= 0;
			elsif rising_edge(clk_vga) then  
				if (cnt_sclk < 14) then
					cnt_sclk <= cnt_sclk + 1;
				else
					r_sclk <= not r_sclk;
					cnt_sclk <= 0;
				end if;
			end if;
		end process;
		
		
		-- Serijski prenos 16bitne reci ( Konvertor Paralelno u Serijsko)
		par2ser: ps generic map (16) port map (r_sclk, r_rtsb, data_ena_ps, r_din, data_valid_ps, data_ps);

		-- Baferisanje signala trajanja 16 taktova u 16bitnu rec
		ser2par: sp generic map (16) port map (r_sclk, r_rtsb, data_ena_sp, r_dout, data_valid_sp, data_sp);
		
		-- Kontroler koji generise i sinhronise signale za rad sa AD konvertorom
		adc_controler: adccontroler generic map (31) port map (reset , r_sclk, data_ena_ps, data_ena_sp, cs, r_din, r_sample_clk, r_sample);
	
		--Vga sinhronizacija i pll
		vga_pll : pll_65 port map (clk_50mhz, reset, clk_vga);
		sync : vga_sync port map (clk_vga, reset, VGA_HS, VGA_VS, VGA_SYNC_N, VGA_BLANK_N, hpos, vpos, Rval, Gval, Bval, VGA_R, VGA_G, VGA_B);

		VGA_CLK <= clk_vga;

		
		
	
		--Proces koji kreira 60hz od 80640hz
		process (r_sample_clk,reset,r_sample)	is
		begin
			if (reset='1') then
				clk_60hz <= '0';
				cnt_60hz <= 0;
			elsif rising_edge(r_sample_clk) then  
				if (cnt_60hz < 677) then
					cnt_60hz <= cnt_60hz + 1;
				else
					clk_60hz <= not clk_60hz;
					cnt_60hz <= 0;
				end if;
			end if;
		end process;
		
		--Kontrolise koji od bafera ce biti aktivan (menja signal rd)
		process (clk_60hz,reset,r_sample)	is
		begin
			if (reset='1'  or r_sample = '0') then
				rd_wr <= '0';
			elsif rising_edge(clk_60hz ) then  
				rd_wr <= not rd_wr;
			end if;
		end process;
		
		rd_wr_n <= not rd_wr;
		
		-- Bafer 1 (cita rd_wr = '1', suprotno ispisuje)
		buffer1 : sample_buffer port map (reset, r_sample, clk_vga, r_sample_clk, rd_wr, data_sp(11 downto 0), hpos, data_buffer1);
		
		-- Bafer 2 (cita rd_wr = '0' (rd_wr1 = '1'), suprotno ispisuje)
		buffer2 : sample_buffer port map (reset, r_sample, clk_vga, r_sample_clk,  rd_wr_n, data_sp(11 downto 0), hpos, data_buffer2);
		
		process (rd_wr) 
		begin
			if (rd_wr = '1') then
				data_buffer <= data_buffer2;
			else 
				data_buffer <= data_buffer1;
			end if;
		end process;
		
		process (hpos,vpos)  
		begin 
				if (806-vpos = to_integer(unsigned(data_buffer))/2+20)	then
					Rval <= x"00";
					Gval <= x"FF";
					Bval <= x"00";
				else 	
					Rval <= x"00";
					Gval <= x"00";
					Bval <= x"00";
							
				end if;
			
		end process;
		
		
		
end architecture;
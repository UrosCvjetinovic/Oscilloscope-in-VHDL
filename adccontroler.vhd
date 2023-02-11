library ieee;
use ieee.std_logic_1164.all;


entity adccontroler is
		generic(
			N_clk          : integer:= 31
		);
		port (
			reset				:	in	 std_logic;			-- Asinhroni reset
			sclk				:	in  std_logic;			-- Klok koji je 18 puta veci od kloka odabiranja
			
			--Enable signlai koji koriste za uspesnu sinhrnonizaciju AD konvertora sa P2S i S2P
			o_data_ena_ps	:	out std_logic;		
			o_data_ena_sp	:	out std_logic;
			--CS signal koji kontrolise komunikaciju sa AD konvertorm
			o_cs				:	out std_logic;	--Aktivan na nuli
			--16bitna rec koja se prosledjuje kontrolnom registru (zavisi od rezima rada)
			o_din				:	out std_logic_vector(15 downto 0);
			--Signal takta odabiranja
			sample_clk		:	out std_logic;
			--Signal koji dozvoljava rad baferima 
			sample			:	out std_logic
			
		);
end adccontroler;

architecture behav of adccontroler is

	type state_type is (startup_mode, normal_mode);		-- Dva rezima rada komunikacije sa AD
	signal state_reg, next_state: state_type;				--		Startup, je rezim potreban da uspostavi signale, validne odabirke pri paljenju
																		--		Nomral,  je rezim u kom AD konvertor radi normalno
	constant dummy_num 	: integer:= 3;
	signal sam_clk 		: std_logic;
	signal count_dummy	: integer range 0 to 3	:=	0;
	signal count_clk		: integer range 0 to N_clk	:=	0;
	signal count			: integer range 0 to N_clk	:=	0;
	
begin
	sample_clk	<= sam_clk;
	
	sample_clk_lab : process (sclk, reset) is		--broji se da bi se kreirao klok odabiranja
		begin													--	i da bi se preskocila prva 3 odabirka, 
		if (reset = '1') then
			count_clk <= 0;
		elsif (sclk'event and sclk = '1') then
			if (count_clk < N_clk-1) then
				count_clk <= count_clk + 1; 
			else
				count_clk <= 0;
				if (count_dummy < dummy_num) then 
					count_dummy <= count_dummy + 1;	-- Prva 3 odabirka posle reseta se ignorisu
																-- 	tome sluzi ovaj brojac
				end if;
			end if;
		end if;
	end process;
	
	
	state_transition: process (sclk, reset) is
		begin
			if (reset = '1') then
				state_reg <= startup_mode;
			elsif (rising_edge(sclk)) then
				state_reg <= next_state;
			end if;
	end process;
	
	next_state_logic: process (count_dummy, state_reg) is
		begin
			case (state_reg) is
				when startup_mode =>
					if (count_dummy >= dummy_num) then	-- Nakon sto prodju 3 odabirka od paljenja
						next_state <= normal_mode;			--		adc pocinje sa normalnim radom
					else
						next_state <= state_reg;
					end if;
				when normal_mode =>
					next_state <= state_reg;
			end case;
	end process;
	
	generator_signala: process (sclk, reset) is
		begin
			if (reset = '1') then
				o_cs 				<= '1';
				count 			<=  0 ;
				o_data_ena_ps	<= '0';
				o_data_ena_sp	<= '0';
				sam_clk 			<= '0';
				o_din				<= "1000001100010000";
			elsif (rising_edge(sclk)) then
				case (state_reg) is
					when startup_mode =>
						if(count_dummy < 2) then			-- Zastita pri paljenju
							o_din <= "1111111111111111";	-- 	vec pri trecem se salje validan DIN
						else
							o_din <= "1000001100010000";	-- normal mode rezim AD
						end if;									
					when normal_mode =>
						o_din <= "1000001100010000";
				end case;
				-- Generisu se signali potrebni za sinhronizovan rad P2S i S2P
				if (count = 0) then 
					o_data_ena_ps <= '1';
					o_data_ena_sp <= '1';
				elsif (count = 1) then
					o_data_ena_ps 	<= '0';
					o_cs 				<= '0';
				elsif (count = 16) then
					o_data_ena_sp 	<= '0';
				elsif (count = 17) then
					o_cs <= '1';
				end if;
				if ( count = (N_clk+1)/2) then 
					sam_clk <= not sam_clk;
				end if;
				
				if (count = N_clk - 1) then
					sam_clk 	<= not sam_clk;	-- klok odabiranja
					count 	<= 0;
				else 
					count 	<= count + 1;
				end if;
			end if;
	end process;
	

	output_logic: process (reset, sclk) is
		begin
			if (reset = '1') then
				sample 	<= '0';
			elsif (rising_edge(sclk)) then
				case (state_reg) is
					when startup_mode =>
					when normal_mode =>
					sample <= '1';				-- pocne da radi bafer (signal dozvole odabiranja)
				end case;
			end if;
			
	end process;
	
end architecture;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.PCK_CRC32_D4.all;


entity eth_tx_main is
    Port ( clk : in  STD_LOGIC; -- 100mhz clk signal 
			  --eth_tx_clk : in  STD_LOGIC; -- 25mhz clk signal 
           tx_start : in  STD_LOGIC; -- signal for sending order
           --tx_payload : in  STD_LOGIC_VECTOR (3 downto 0); --data carried from BRAM ----not used for now 
           tx_d : out  STD_LOGIC_VECTOR (3 downto 0); -- data sent to MII 
           tx_en  : out  STD_LOGIC			  --singal for sending to MII
           --tx_payload_ctr : OUT  STD_LOGIC_VECTOR (13 downto 0)); -- carying payload address / index ----not used for now 
	);
end eth_tx_main;

architecture Behavioral of eth_tx_main is

	constant eth_data_len: integer := 92; -- Number of nibbles (16384 is maximum in nexys3)
	
	type eth_preamble_type is array (0 to 15) of std_logic_vector(3 downto 0);
	constant eth_preamble: eth_preamble_type := (
-- Preamble + SFD
	x"5",x"5", x"5",x"5", x"5",x"5", x"5",x"5", x"5",x"5", x"5",x"5", x"5",x"5", x"D",x"5");  
	
-- Header (Ether (14), IP (20) , UDP (8) -> 42)
   type eth_header_type is array(0 to 83) of std_logic_vector(3 downto 0);
   constant eth_header: eth_header_type := (
-- Destination Ether: 
	x"4",x"0", x"C",x"2", x"B",x"A", x"0",x"F", x"9",x"A", x"D",x"7",
	--x"F",x"F", x"F",x"F", x"F",x"F", x"F",x"F", x"F",x"F", x"F",x"F",
-- Source Ether: 00:18:3E:01:02:03
	x"0",x"0", x"1",x"8", x"3",x"E", x"0",x"1", x"0",x"2", x"0",x"3", 
-- Ether type
   x"0",x"8", x"0",x"0", 
-- IP header Total Length = 74 (0x004A) 
	 x"4",x"5", x"0",x"0", x"0",x"0", x"4",x"A", x"0",x"0", x"0",x"0", 
    x"4",x"0", x"0",x"0", x"4",x"0", x"1",x"1", 
-- IP checksum
	 x"2",x"6", x"9",x"5",
-- Source IP, Dest IP
	 x"0",x"A", x"0",x"0", x"0",x"0", x"0",x"A", x"0",x"A", x"0",x"0", x"0",x"0", x"0",x"5",
-- UDP header Ports 4660, Length 54 (0x0036)
	 x"1",x"2", x"3",x"4", x"1",x"2", x"3",x"4", x"0",x"0", x"3",x"6", x"0",x"0", x"0",x"0"
--END OF LAYERS PACKET STRUCTURE 
);

type text_rom_t is array (0 to 45) of std_logic_vector(7 downto 0);
constant TEXT_ROM : text_rom_t := (
    x"48", x"45", x"4C", x"4C", x"4F", -- HELLO
    x"20", x"46", x"50", x"47", x"41", --  FPGA
    x"20", x"55", x"44", x"50", x"20", --  UDP 
    x"54", x"45", x"53", x"54", -- TEST
    others => x"2E" -- Pad with '.'
);
	constant eth_header_len: integer := 84; -- Number of nibbles
   signal crc_calc: std_logic_vector(31 downto 0); -- RELATED TO CRC CALC.
	constant tx_tail: integer := 200; -- GAP time at end of each transimtion and before idle
	
    type tx_state_type is (preamble, header, data, crc, tail, idle); -- states used 
    signal tx_state: tx_state_type := idle; --states start at idle state 
    signal tx_cnt: unsigned (13 downto 0) := (others => '0'); -- all bits start with 0 
    signal tx_start1: std_logic := '0'; -- both tx_start1/2 are 2-FF synchronizer, their role is to Prevents metastability
    signal tx_start2: std_logic := '0';

begin
    --tx_payload_ctr <= std_logic_vector(tx_cnt); --Send payload nibble number tx_cnt , tx_payload_ctr COUNT NIBBLES
	 process(clk)
		variable txd: std_logic_vector(3 downto 0); -- used for the tx_d logic inside the process
		variable current_byte : std_logic_vector(7 downto 0);
	 begin
        if clk'event and clk='1' then
            tx_start1 <= tx_start; -- 2-FF synchronizer
            tx_start2 <= tx_start1; -- 2-FF synchronizer
            case tx_state is
                when preamble =>
                    tx_en <= '1';
						  tx_d <= eth_preamble(to_integer(tx_cnt(7 downto 1) & not tx_cnt(0)));
                    if tx_cnt < 15 then
                        tx_cnt <= tx_cnt + 1;
						  else
                        tx_cnt <= (others => '0');
                        tx_state <= header;
                        crc_calc <= (others => '1'); -- Preset the CRC with all '1'
                    end if;
                when header =>
                    tx_en <= '1';
						  txd  := eth_header (to_integer(tx_cnt(7 downto 1) & not tx_cnt(0)));
                    tx_d <= txd;
                    crc_calc <= nextCRC32_D4(txd, crc_calc);
                    if tx_cnt < eth_header_len - 1 then
                        tx_cnt <= tx_cnt + 1;
						  else 
                        tx_cnt <= (others => '0');
                        tx_state <= data;
                    end if;
                when data => 
                    tx_en <= '1';						  
						  current_byte := TEXT_ROM(to_integer(tx_cnt(13 downto 1)));
        
							if tx_cnt(0) = '0' then
								txd := current_byte(3 downto 0); -- Low Nibble First
							else
								txd := current_byte(7 downto 4); -- High Nibble Second
							end if;
--                    txd := eth_data(to_integer(tx_cnt(7 downto 1) & not tx_cnt(0)));
--                    txd := tx_payload;
                    tx_d <= txd;
                    crc_calc <= nextCRC32_D4(txd, crc_calc);
						  
                    if tx_cnt < eth_data_len - 1 then
                        tx_cnt <= tx_cnt + 1;
                    else
                        tx_cnt <= (others => '0');
                        tx_state <= crc;
                    end if;
						  
						  
                when crc => 
                    tx_en <= '1';
                    tx_cnt <= tx_cnt + 1;
                    case tx_cnt is
								when "00000000000000" =>
                            txd := crc_calc(31 downto 28);
                        when "00000000000001" =>
                            txd := crc_calc(27 downto 24);
                        when "00000000000010" =>
                            txd := crc_calc(23 downto 20);
								when "00000000000011" =>
                            txd := crc_calc(19 downto 16);
                        when "00000000000100" =>
                            txd := crc_calc(15 downto 12);
                        when "00000000000101" =>
									 txd := crc_calc(11 downto 8);
                        when "00000000000110" =>
                            txd := crc_calc(7 downto 4);
                        when others =>
                            txd := crc_calc(3 downto 0);
                            tx_cnt <= (others => '0');
                            tx_state <= tail;
                    end case;
                    -- Invert the CRC before transmitting
                    -- Bitswap so bit C(32) is the first to be transmitted
							 tx_d(0) <= not txd(3);
							 tx_d(1) <= not txd(2);
						  	 tx_d(2) <= not txd(1);
                      tx_d(3) <= not txd(0);

                when tail =>
                    tx_en <= '0';
                    tx_d <= "0000";
                    if tx_cnt < tx_tail - 1 then
                        tx_cnt <= tx_cnt + 1;
                    else
                        tx_cnt <= (others => '0');
                        tx_state <= idle;
                    end if;
                when idle =>
                    tx_en <= '0';
                    tx_d <= "0000";
                    if tx_start2 = '1' then
                        tx_state <= preamble;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;


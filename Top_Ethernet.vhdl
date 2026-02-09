library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- No need to use eth_tx_main.all since we use entity work instantiation [cite: 92]

entity Top_Ethernet is
    Port ( 
        clk_100MHz : in  STD_LOGIC; -- Pin V10 
        phy_tx_clk : in  STD_LOGIC; -- Pin L5 (25MHz from PHY) [cite: 88, 111]
        btn_reset  : in  STD_LOGIC; -- Pin B8 (Active High) 
        btn_send   : in  STD_LOGIC; -- Pin D9 [cite: 88, 114]
        phy_tx_err : out STD_LOGIC := '0'; -- Add this
        -- MII Pins
        phy_rst_n  : out STD_LOGIC; -- Pin P3 [cite: 88, 89]
        phy_tx_en  : out STD_LOGIC; -- Pin L2 [cite: 88, 115]
        phy_tx_data: out STD_LOGIC_VECTOR (3 downto 0); -- T1, T2, U1, U2
        
        -- Debug LEDs
        Leds       : out STD_LOGIC_VECTOR (3 downto 0)
    );
end Top_Ethernet;

architecture Behavioral of Top_Ethernet is
    -- Internal signals for clock management and debugging
    signal tx_en_internal : std_logic; 
    signal por_counter    : unsigned(19 downto 0) := (others => '0'); -- For ~10ms reset delay
    signal heartbeat_25   : unsigned(23 downto 0) := (others => '0'); 
    signal heartbeat_100  : unsigned(24 downto 0) := (others => '0');
begin
--	phy_tx_err <= '0';
    -- 1. POWER-ON RESET (MANAGED BY 100 MHz)
    -- This holds the PHY in reset (Low) for a short time after power-up.
    -- This prevents the "Deadlock" where the PHY and FPGA wait for each other.
    process(clk_100MHz)
    begin
        if rising_edge(clk_100MHz) then
            if btn_reset = '1' then
                por_counter <= (others => '0');
                phy_rst_n <= '0';
            elsif por_counter < x"FFFFF" then 
                por_counter <= por_counter + 1;
                phy_rst_n <= '0'; -- Hold Reset Low [cite: 91, 92]
            else
                phy_rst_n <= '1'; -- Release Reset (High) [cite: 91]
            end if;
        end if;
    end process;

    -- 2. ETHERNET ENGINE (MANAGED BY 25 MHz)
    -- This module only works when the PHY is awake and sending phy_tx_clk.
    Ethernet_Engine : entity work.eth_tx_main
        port map (
            clk      => phy_tx_clk, 
            tx_start => btn_send, 
            tx_d     => phy_tx_data, 
            tx_en    => tx_en_internal 
        );

    -- Drive the physical pins
    phy_tx_en <= tx_en_internal;

    -- 3. DIAGNOSTIC HEARTBEATS
    -- Blink Leds(3) to prove 100MHz is alive
    process(clk_100MHz) begin
        if rising_edge(clk_100MHz) then heartbeat_100 <= heartbeat_100 + 1; end if;
    end process;
    
    -- Blink Leds(2) to prove 25MHz is alive (If this stays OFF, the PHY isn't linked)
    process(phy_tx_clk) begin
        if rising_edge(phy_tx_clk) then heartbeat_25 <= heartbeat_25 + 1; end if;
    end process;

    -- LED Assignments
    Leds(0) <= tx_en_internal; -- Should blink extremely fast when sending [cite: 93]
    Leds(1) <= phy_tx_clk;     -- Very dim (25MHz toggle) but confirms clock presence
    Leds(2) <= heartbeat_25(22);  -- Slow blink = PHY is linked and providing clock
    Leds(3) <= heartbeat_100(23); -- Slow blink = FPGA 100MHz is working

end Behavioral;

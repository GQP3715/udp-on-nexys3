library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Top_Ethernet_tb is
end Top_Ethernet_tb;

architecture Behavioral of Top_Ethernet_tb is
    -- Component Declaration
    component Top_Ethernet
        Port ( 
            clk_100MHz : in  STD_LOGIC;
            phy_tx_clk : in  STD_LOGIC;
            btn_reset  : in  STD_LOGIC;
            btn_send   : in  STD_LOGIC;
            phy_rst_n  : out STD_LOGIC;
            phy_tx_en  : out STD_LOGIC;
            phy_tx_data: out STD_LOGIC_VECTOR (3 downto 0);
            Leds       : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    -- Testbench Signals
    signal clk_100MHz : std_logic := '0';
    signal phy_tx_clk : std_logic := '0';
    signal btn_reset  : std_logic := '0';
    signal btn_send   : std_logic := '0';
    signal phy_rst_n  : std_logic;
    signal phy_tx_en  : std_logic;
    signal phy_tx_data: std_logic_vector(3 downto 0);
    signal Leds       : std_logic_vector(3 downto 0);

    -- Clock constants
    constant clk_100_period : time := 10 ns; -- 100 MHz
    constant clk_25_period  : time := 40 ns; -- 25 MHz (MII Standard)

begin
    -- Instantiate the Unit Under Test (UUT)
    uut: Top_Ethernet
        port map (
            clk_100MHz => clk_100MHz,
            phy_tx_clk => phy_tx_clk,
            btn_reset  => btn_reset,
            btn_send   => btn_send,
            phy_rst_n  => phy_rst_n,
            phy_tx_en  => phy_tx_en,
            phy_tx_data=> phy_tx_data,
            Leds       => Leds
        );

    -- 100MHz Clock generation
    clk_100_process : process
    begin
        clk_100MHz <= '0';
        wait for clk_100_period/2;
        clk_100MHz <= '1';
        wait for clk_100_period/2;
    end process;

    -- 25MHz Clock generation (Provided by PHY in real hardware)
    phy_clk_process : process
    begin
        phy_tx_clk <= '0';
        wait for clk_25_period/2;
        phy_tx_clk <= '1';
        wait for clk_25_period/2;
    end process;

    -- Stimulus Process
    stim_proc: process
    begin		
        -- 1. Power-on State
        btn_reset <= '0';
        wait for 100 ns;
        
        -- 2. Observe phy_rst_n
        -- It should be '0' initially and flip to '1' after the counter
        wait until phy_rst_n = '1';
        report "PHY Reset Released!";
        wait for 1 us;

        -- 3. Trigger Packet Transmission
        btn_send <= '1';
        wait for 100 ns; -- Simulated button press
        btn_send <= '0';

        -- 4. Wait to see the full packet
        -- Total packet is roughly 200-300 nibbles (8-12 microseconds)
        wait for 15 us;

        report "Simulation Finished. Check the Waveform for CRC dbe872b7 sequence.";
        wait;
    end process;

end Behavioral;

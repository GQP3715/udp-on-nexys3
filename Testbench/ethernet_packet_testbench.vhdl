library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Example Testbench Structure
entity testbench is
end testbench;

architecture sim of testbench is
    signal clk      : std_logic := '0';
    signal tx_start : std_logic := '0';
    signal tx_d     : std_logic_vector(3 downto 0);
    signal tx_en    : std_logic;
begin
    -- Clock Generation (25 MHz = 40ns period)
    clk <= not clk after 20 ns;

    uut: entity work.eth_tx_main
        port map (
            clk      => clk,
            tx_start => tx_start,
            tx_d     => tx_d,
            tx_en    => tx_en
        );

    process
    begin
        wait for 100 ns;
        tx_start <= '1';
        wait for 40 ns;
        tx_start <= '0';
        wait;
    end process;
end sim;

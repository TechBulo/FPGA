----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2017/03/14 15:37:33
-- Design Name: 
-- Module Name: uart - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart is
    generic 
    (
       baud                : positive   :=  921600;
       clock_frequency     : positive   :=  100000000
    );
    port 
    (
        i_clk                 :   in  std_logic;
        i_rst_n               :   in  std_logic;    
        
        o_data                :   out std_logic_vector(7 downto 0); 
        o_data_check          :   out std_logic;
        o_data_valid          :   out std_logic;
        
        i_data_load           :   in  std_logic;
        i_data                :   in  std_logic_vector(7 downto 0);  
        o_tx_busy             :   out std_logic;  
          
        o_tx                  :   out std_logic;
        i_rx                  :   in  std_logic
    );
end entity uart;

architecture Behavioral of uart is

    ---------------------------------------------------------------------------
    -- Baud generation constants
    ---------------------------------------------------------------------------
    constant c_tx_div       :   integer := clock_frequency / baud;
    constant c_rx_div       :   integer := clock_frequency / (baud * 16);
    constant c_tx_div_width :   integer := integer(log2(real(c_tx_div))) + 1;   
    constant c_rx_div_width :   integer := integer(log2(real(c_rx_div))) + 1;
    
    ---------------------------------------------------------------------------
    -- Baud generation signals
    ---------------------------------------------------------------------------
    signal tx_baud_counter  : unsigned(c_tx_div_width - 1 downto 0) := (others => '0');   
    signal tx_baud_tick     : std_logic := '0';
    signal rx_baud_counter  : unsigned(c_rx_div_width - 1 downto 0) := (others => '0');   
    signal rx_baud_tick     : std_logic := '0';
    ---------------------------------------------------------------------------
    -- Transmitter signals
    ---------------------------------------------------------------------------
    type uart_tx_states is ( 
       tx_send_start_bit,
       tx_send_data,
       tx_send_stop_bit
    );             
    signal uart_tx_state : uart_tx_states := tx_send_start_bit;
    signal uart_tx_data_vec : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_tx_data : std_logic := '1';
    signal uart_tx_count : unsigned(2 downto 0) := (others => '0');
    signal uart_tx_busy  : std_logic := '0';

    ---------------------------------------------------------------------------
    -- Receiver signals
    ---------------------------------------------------------------------------
    type uart_rx_states is ( 
        rx_get_start_bit, 
        rx_get_data, 
        rx_get_check,
        rx_get_stop_bit
    );            
    signal uart_rx_state : uart_rx_states := rx_get_start_bit;
    signal uart_rx_bit : std_logic := '1';
    signal uart_rx_data_vec : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_rx_data_check : std_logic := '1';
    signal uart_rx_data_sr : std_logic_vector(1 downto 0) := (others => '1');
    signal uart_rx_filter : unsigned(1 downto 0) := (others => '1');
    signal uart_rx_count  : unsigned(2 downto 0) := (others => '0');
    signal uart_rx_data_out_valid : std_logic := '0'; 
    signal uart_rx_bit_spacing : unsigned (3 downto 0) := (others => '0');
    signal uart_rx_bit_tick : std_logic := '0';      
       
begin
    ---------------------------------------------------------------------------
    -- OVERSAMPLE_CLOCK_DIVIDER
    -- generate an oversampled tick (baud * 16)
    ---------------------------------------------------------------------------
    oversample_clock_divider : process (i_rst_n, i_clk)
    begin
        if rising_edge (i_clk) then
            if i_rst_n = '0' then
                rx_baud_counter <= (others => '0');
                rx_baud_tick <= '0';    
            else
                if rx_baud_counter = c_rx_div then
                    rx_baud_counter <= (others => '0');
                    rx_baud_tick <= '1';
                else
                    rx_baud_counter <= rx_baud_counter + 1;
                    rx_baud_tick <= '0';
                end if;
            end if;
        end if;
    end process oversample_clock_divider; 
    
    ---------------------------------------------------------------------------
    -- RXD_SYNCHRONISE
    -- Synchronise rxd to the oversampled baud
    ---------------------------------------------------------------------------
    rxd_synchronise : process(i_rst_n, i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                uart_rx_data_sr <= (others => '1');
            else
                if rx_baud_tick = '1' then
                    uart_rx_data_sr(0) <= i_rx;
                    uart_rx_data_sr(1) <= uart_rx_data_sr(0);
                end if;
            end if;
        end if;
    end process rxd_synchronise;
    
    ---------------------------------------------------------------------------
    -- RXD_FILTER
    -- Filter rxd with a 2 bit counter.
    ---------------------------------------------------------------------------
    rxd_filter : process(i_rst_n, i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                uart_rx_filter <= (others => '1');
                uart_rx_bit <= '1';
            else
                if rx_baud_tick = '1' then
                    -- filter rxd.
                    if uart_rx_data_sr(1) = '1' and uart_rx_filter < 3 then
                        uart_rx_filter <= uart_rx_filter + 1;
                    elsif uart_rx_data_sr(1) = '0' and uart_rx_filter > 0 then
                        uart_rx_filter <= uart_rx_filter - 1;
                    end if;
                    -- set the rx bit.
                    if uart_rx_filter = 3 then
                        uart_rx_bit <= '1';
                    elsif uart_rx_filter = 0 then
                        uart_rx_bit <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process rxd_filter;
    
    ---------------------------------------------------------------------------
    -- RX_BIT_SPACING
    ---------------------------------------------------------------------------
    rx_bit_spacing : process (i_clk)
    begin
        if rising_edge(i_clk) then
            uart_rx_bit_tick <= '0';
            if rx_baud_tick = '1' then       
                if uart_rx_bit_spacing = 15 then
                    uart_rx_bit_tick <= '1';
                    uart_rx_bit_spacing <= (others => '0');
                else
                    uart_rx_bit_spacing <= uart_rx_bit_spacing + 1;
                end if;
                if uart_rx_state = rx_get_start_bit then
                    uart_rx_bit_spacing <= (others => '0');
                end if; 
            end if;
        end if;
    end process rx_bit_spacing;
    
    ---------------------------------------------------------------------------
   -- UART_RECEIVE_DATA
   ---------------------------------------------------------------------------
   uart_receive_data   : process(i_rst_n, i_clk)
   begin
       if rising_edge(i_clk) then
           if i_rst_n = '0' then
               uart_rx_state <= rx_get_start_bit;
               uart_rx_data_vec <= (others => '0');
               uart_rx_data_check   <=  '0';
               uart_rx_count <= (others => '0');
               uart_rx_data_out_valid <= '0';
           else
               uart_rx_data_out_valid <= '0';
               case uart_rx_state is
                   when rx_get_start_bit =>
                       if rx_baud_tick = '1' and uart_rx_bit = '0' then
                           uart_rx_state <= rx_get_data;
                       end if;
                   when rx_get_data =>
                       if uart_rx_bit_tick = '1' then
                           uart_rx_data_vec(uart_rx_data_vec'high)   <= uart_rx_bit;
                           uart_rx_data_vec( uart_rx_data_vec'high-1 downto 0) <= uart_rx_data_vec( uart_rx_data_vec'high downto 1);
                           if uart_rx_count < 7 then
                               uart_rx_count   <= uart_rx_count + 1;
                           else
                               uart_rx_count <= (others => '0');
                               uart_rx_state <= rx_get_check;
                           end if;
                       end if;
                   when rx_get_check =>
                         if uart_rx_bit_tick = '1' then
                             uart_rx_data_check   <=  uart_rx_bit;
                             uart_rx_state <= rx_get_stop_bit;  
                         end if;
                   when rx_get_stop_bit =>
                       if uart_rx_bit_tick = '1' then
                           if uart_rx_bit = '1' then
                               uart_rx_state <= rx_get_start_bit;
                               uart_rx_data_out_valid <= '1';
                           end if;
                       end if;                            
                   when others =>
                       uart_rx_state <= rx_get_start_bit;
               end case;
           end if;
       end if;
   end process uart_receive_data;
   
   ---------------------------------------------------------------------------
   -- TX_CLOCK_DIVIDER
   -- Generate baud ticks at the required rate based on the input clock
   -- frequency and baud rate
   ---------------------------------------------------------------------------
   tx_clock_divider : process (i_rst_n, i_clk)
   begin
       if rising_edge (i_clk) then
           if i_rst_n = '0' then
               tx_baud_counter <= (others => '0');
               tx_baud_tick <= '0';    
           else
               if tx_baud_counter = c_tx_div then
                   tx_baud_counter <= (others => '0');
                   tx_baud_tick <= '1';
               else
                   tx_baud_counter <= tx_baud_counter + 1;
                   tx_baud_tick <= '0';
               end if;
           end if;
       end if;
   end process tx_clock_divider;
   
   ---------------------------------------------------------------------------
   -- UART_SEND_DATA 
   -- Get data from data_stream_in and send it one bit at a time upon each 
   -- baud tick. Send data lsb first.
   -- wait 1 tick, send start bit (0), send data 0-7, send stop bit (1)
   ---------------------------------------------------------------------------
   uart_send_data : process(i_rst_n, i_clk)
   begin
       if rising_edge(i_clk) then
           if i_rst_n = '0' then
               uart_tx_data <= '1';
               uart_tx_data_vec <= (others => '0');
               uart_tx_count <= (others => '0');
               uart_tx_state <= tx_send_start_bit;
               uart_tx_busy <= '0';
           else
               case uart_tx_state is
                   when tx_send_start_bit =>
                       if tx_baud_tick = '1' and i_data_load = '1' then
                           uart_tx_data  <= '0';
                           uart_tx_state <= tx_send_data;
                           uart_tx_count <= (others => '0');
                           uart_tx_busy <= '1';
                           uart_tx_data_vec <= i_data;
                       end if;
                   when tx_send_data =>
                       if tx_baud_tick = '1' then
                           uart_tx_data <= uart_tx_data_vec(0);
                           uart_tx_data_vec(uart_tx_data_vec'high-1 downto 0) <= uart_tx_data_vec(uart_tx_data_vec'high downto 1);
                           if uart_tx_count < 7 then
                               uart_tx_count <= uart_tx_count + 1;
                           else
                               uart_tx_count <= (others => '0');
                               uart_tx_state <= tx_send_stop_bit;
                           end if;
                       end if;
                   when tx_send_stop_bit =>
                       if tx_baud_tick = '1' then
                           uart_tx_data <= '1';
                           uart_tx_state <= tx_send_start_bit;
                           uart_tx_busy <= '0';
                       end if;
                   when others =>
                       uart_tx_data <= '1';
                       uart_tx_state <= tx_send_start_bit;
               end case;
           end if;
       end if;
   end process uart_send_data;   
   
    -- Connect IO
    o_data_valid  <=  uart_rx_data_out_valid;
    o_data_check  <=  uart_rx_data_check;
    o_data        <=  uart_rx_data_vec;
    o_tx          <=  uart_tx_data;
    o_tx_busy     <=  uart_tx_busy;  
    
end Behavioral;

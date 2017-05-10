----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2017/03/16 14:32:22
-- Design Name: 
-- Module Name: ad_spi_master - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ad_spi_master is
    generic 
    (
       spi_clk_divide      : positive   :=  10;            --  SPI clock divisor,
       spi_data_length     : positive   :=  8              --  SPI data length
 --    clock_frequency     : positive   :=  100000000;
    );
    port
    (
        --+ CPU Interface Signals
        i_clk               :   in  std_logic;
        i_rst_n             :   in  std_logic;
        i_data              :   in  std_logic_vector(spi_data_length - 1 downto 0);
        o_data              :   out std_logic_vector(spi_data_length - 1 downto 0);
        
        --+ SPI Ctrl Signals
        i_cpol              :   in  std_logic;      -- SPI clock polarity 
        i_cpha              :   in  std_logic;      -- SPI clock phase
        
        i_start             :   in  std_logic;
        o_busy              :   out std_logic;      -- Currently transmitting data
        o_recv_valid        :   out std_logic;      
        
        --+ SPI Interface Signals
        i_spi_miso          :   in  std_logic;
        o_spi_mosi          :   out std_logic;
        o_spi_clk           :   out std_logic;
        o_spi_cs_n          :   out std_logic
    );
end ad_spi_master;

architecture Behavioral of ad_spi_master is
    ---------------------------------------------------------------------------
    -- Baud generation signals
    ---------------------------------------------------------------------------
    signal sclk_counter         : std_logic_vector(3 downto 0);  
    signal sclk_duty_counter    : std_logic_vector(3 downto 0);    
    ---------------------------------------------------------------------------
    
    signal spi_clk_buf     : std_logic;      -- Buffered SPI clock
    signal spi_clk_out     : std_logic;      -- Buffered SPI clock output
    signal prev_spi_clk    : std_logic;      -- Previous SPI clock state
    signal sclk_send_toogle: std_logic;
    signal sclk_recv_toogle: std_logic;
    
    signal spi_cs_n          : std_logic;
    
    signal tx_shift_reg       : std_logic_vector(spi_data_length - 1 downto 0);       -- Shift register
    signal rx_shift_reg       : std_logic_vector(spi_data_length - 1 downto 0);       -- Shift register
    signal transfer_count     : std_logic_vector(3 downto 0);          -- Number of bits transfered

    type   state_type is (s_idle, s_cs_valid, s_cs_devalid, s_running);       --* State type of the SPI transfer state machine
    signal state           : state_type;
begin
    
    --*Generate SPI clock
    spi_clock_gen : process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            sclk_counter   <= (others => '0');
            sclk_duty_counter   <=  conv_std_logic_vector(shr(conv_unsigned(spi_clk_divide, 4), "1"), 4)  - 1;
            spi_clk_buf   <= i_cpol;  --空闲时钟极性控制
        elsif rising_edge(i_clk) then
            if state /= s_idle then
              if (sclk_counter = sclk_duty_counter)   then
                spi_clk_buf <= not spi_clk_buf;
                sclk_counter <= (others => '0');
              else
                sclk_counter <= sclk_counter + 1;
              end if;
            else
              spi_clk_buf <= i_cpol;
            end if;
        end if;
    end process;
    
    --* SPI transfer state machine
    spi_proc : process(i_clk, i_rst_n)
    begin
    if i_rst_n = '0' then
      transfer_count        <= (others => '0');
      tx_shift_reg          <= (others => '0');
      rx_shift_reg          <= (others => '0');
      prev_spi_clk          <= i_cpol;
      spi_clk_out           <= i_cpol;
      sclk_send_toogle      <= '0';
      sclk_recv_toogle      <= '0';
      spi_cs_n              <= '1';
      state                 <= s_idle;
      o_busy                <= '0';
      o_recv_valid          <= '0';
    elsif rising_edge(i_clk) then
      prev_spi_clk <= spi_clk_buf;
      case state is
        when s_idle =>
          if i_start = '1' then
            transfer_count     <= (others => '0');
            tx_shift_reg       <= i_data;
            state              <= s_cs_valid;
            o_busy             <= '1';
            o_recv_valid   <=  '0';
          end if;
        when s_cs_valid =>
            spi_cs_n           <= '0';
            state              <= s_running;
        when s_running =>
          if i_cpha = '0'   then   --第一个沿发送数据，第二个沿接收数据
             if prev_spi_clk = i_cpol and spi_clk_buf = not i_cpol then    --第一个沿
                sclk_send_toogle    <=  '1';
                o_spi_mosi     <= tx_shift_reg(spi_data_length - 1); 
                tx_shift_reg   <= tx_shift_reg(spi_data_length - 2 downto 0) & '0';
             end if;
             if sclk_send_toogle = '1'  then
                sclk_send_toogle    <=  '0';
                spi_clk_out <=  not spi_clk_out;
             end if;
             if prev_spi_clk = not i_cpol and spi_clk_buf = i_cpol then    --第二个沿
                spi_clk_out <=  not spi_clk_out;
                sclk_recv_toogle    <=  '1';
             end if;   
              if sclk_recv_toogle = '1'  then
                sclk_recv_toogle    <=  '0';
                rx_shift_reg         <= rx_shift_reg(spi_data_length - 2 downto 0) & i_spi_miso;
                transfer_count       <= transfer_count +  1;
                if (transfer_count = std_logic_vector(conv_unsigned(spi_data_length - 1, 4)))  then
                    state     <= s_cs_devalid;
                end if; 
             end if;
          else                     --第一个沿接收数据，第二个沿发送数据
             if prev_spi_clk = i_cpol and spi_clk_buf = not i_cpol then    --第一个沿
                spi_clk_out <=  not spi_clk_out;
                sclk_recv_toogle    <=  '1';
              end if;
              if sclk_recv_toogle = '1'  then
                  sclk_recv_toogle    <=  '0';
                  rx_shift_reg         <= rx_shift_reg(spi_data_length - 2 downto 0) & i_spi_miso;
              end if;
              if prev_spi_clk = not i_cpol and spi_clk_buf = i_cpol then    --第二个沿
                  sclk_send_toogle    <=  '1';
                  o_spi_mosi     <= tx_shift_reg(spi_data_length - 1); 
                  tx_shift_reg   <= tx_shift_reg(spi_data_length - 2 downto 0) & '0';
              end if;
              if sclk_send_toogle = '1'  then
                 sclk_send_toogle    <=  '0';
                 spi_clk_out <=  not spi_clk_out;
                 transfer_count       <= transfer_count +  1;
                 if (transfer_count = std_logic_vector(conv_unsigned(spi_data_length - 1, 4)))  then
                     state     <= s_cs_devalid;
                 end if; 
              end if;
          end if;
         when s_cs_devalid =>
             o_busy         <= '0';
             spi_cs_n       <= '1';
             state          <= s_idle;
             o_recv_valid   <=  '1';
        when others =>
          null;
      end case;
    end if;
    end process;
    
    o_spi_clk   <=  spi_clk_out;
    o_spi_cs_n  <=  spi_cs_n;
    o_data      <=  rx_shift_reg;
    
end Behavioral;

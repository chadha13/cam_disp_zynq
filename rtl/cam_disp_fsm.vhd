-- FSM de supervision camera -> DSI (machine de MEALY : sorties = f(etat, entrees))
-- Etats : IDLE(0) POWER(1) RESET(2) CFG_CAM(3) CFG_DSI(4) RUN(5) FAULT(6)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity cam_disp_fsm is
  generic (PWR_MS : positive := 5;    -- attente apres alimentation
           RST_MS : positive := 25);  -- attente apres reset capteur (SCCB >= 20 ms)
  port (clk, rst_n : in std_logic;
        tick_1ms   : in std_logic;
        start      : in std_logic;  -- niveau : 0 = abandon -> IDLE
        cam_done   : in std_logic;  -- firmware : capteur configure
        dsi_done   : in std_logic;  -- firmware : DSI/D-PHY configures
        fault      : in std_logic;  -- underrun / overflow (collant)
        ack_fault  : in std_logic;  -- firmware : defaut traite
        state_code : out std_logic_vector(2 downto 0);
        cam_pwdn, cam_rst_n, cap_en, stream_en, led_err : out std_logic);
end entity;
architecture rtl of cam_disp_fsm is
  type st_t is (S_IDLE, S_POWER, S_RESET, S_CFG_CAM, S_CFG_DSI, S_RUN, S_FAULT);
  signal st, nx : st_t := S_IDLE;
  signal cnt : natural range 0 to 255 := 0;
  signal waited : boolean;
begin
  waited <= (st = S_POWER and cnt = PWR_MS - 1 and tick_1ms = '1') or
            (st = S_RESET and cnt = RST_MS - 1 and tick_1ms = '1');

  -- transitions
  process (st, start, waited, cam_done, dsi_done, fault, ack_fault) begin
    nx <= st;
    if start = '0' then nx <= S_IDLE;
    else
      case st is
        when S_IDLE    => nx <= S_POWER;
        when S_POWER   => if waited then nx <= S_RESET; end if;
        when S_RESET   => if waited then nx <= S_CFG_CAM; end if;
        when S_CFG_CAM => if cam_done = '1' then nx <= S_CFG_DSI; end if;
        when S_CFG_DSI => if dsi_done = '1' then nx <= S_RUN; end if;
        when S_RUN     => if fault = '1' then nx <= S_FAULT; end if;
        when S_FAULT   => if ack_fault = '1' then nx <= S_CFG_CAM; end if;
      end case;
    end if;
  end process;

  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' then st <= S_IDLE; cnt <= 0;
      else
        st <= nx;
        if nx /= st then cnt <= 0;
        elsif tick_1ms = '1' and cnt < 255 then cnt <= cnt + 1; end if;
      end if;
    end if;
  end process;

  -- sorties de MEALY (dependent aussi des entrees)
  cam_pwdn  <= '1' when (st = S_IDLE and start = '0') else '0';
  cam_rst_n <= '0' when (st = S_IDLE or st = S_POWER or start = '0') else '1';
  cap_en    <= '1' when (st = S_RUN and fault = '0' and start = '1') else '0';
  stream_en <= '1' when (st = S_RUN and fault = '0' and start = '1') else '0';
  led_err   <= '1' when (st = S_FAULT or (st = S_RUN and fault = '1')) else '0';
  with st select state_code <=
    "000" when S_IDLE, "001" when S_POWER, "010" when S_RESET, "011" when S_CFG_CAM,
    "100" when S_CFG_DSI, "101" when S_RUN, "110" when S_FAULT;
end architecture;

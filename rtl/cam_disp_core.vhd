-- Coeur camera -> DSI : capture DVP, FIFO, sortie AXI4-Stream, SCCB, pont AXI4-Lite, FSM de Mealy, PicoBlaze
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity cam_disp_core is
  generic (CLK_HZ : integer := 100_000_000; AW : integer := 17; FIFO_AW : integer := 10;
           FS_RISING : boolean := false; PREFILL : natural := 256; PWR_MS : positive := 5; RST_MS : positive := 25);
  port (clk, rst_n : in std_logic;                        -- horloge controle (= s_axi_aclk du DSI)
        -- camera DVP + SCCB
        cam_pclk, cam_vsync, cam_href : in std_logic; cam_d : in std_logic_vector(7 downto 0);
        cam_sioc : out std_logic; cam_sda_low : out std_logic; cam_sda_in : in std_logic;
        cam_pwdn, cam_rst_n : out std_logic;
        -- AXI4-Lite maitre vers MIPI DSI TX Subsystem (0x0_0000 = controleur, 0x1_0000 = D-PHY)
        m_awaddr : out std_logic_vector(AW-1 downto 0); m_awvalid : out std_logic; m_awready : in std_logic;
        m_wdata : out std_logic_vector(31 downto 0); m_wstrb : out std_logic_vector(3 downto 0);
        m_wvalid : out std_logic; m_wready : in std_logic;
        m_bresp : in std_logic_vector(1 downto 0); m_bvalid : in std_logic; m_bready : out std_logic;
        m_araddr : out std_logic_vector(AW-1 downto 0); m_arvalid : out std_logic; m_arready : in std_logic;
        m_rdata : in std_logic_vector(31 downto 0); m_rresp : in std_logic_vector(1 downto 0);
        m_rvalid : in std_logic; m_rready : out std_logic;
        -- AXI4-Stream video vers DSI (domaine clk_vid)
        clk_vid : in std_logic;
        m_axis_tdata : out std_logic_vector(23 downto 0); m_axis_tvalid : out std_logic; m_axis_tready : in std_logic;
        m_axis_tuser : out std_logic_vector(0 downto 0); m_axis_tlast : out std_logic;
        status : out std_logic_vector(7 downto 0));
end entity;

architecture rtl of cam_disp_core is
  signal rst_c, rstv_n, rstp_n : std_logic;
  signal tick, ms_tick_dummy : std_logic := '0';
  signal tcnt : integer range 0 to CLK_HZ/1000 := 0;
  signal ms_cnt : unsigned(7 downto 0) := (others => '0');
  -- pb <-> blocs
  signal axi_addr : std_logic_vector(AW-1 downto 0); signal axi_wd, axi_rd : std_logic_vector(31 downto 0);
  signal axi_swr, axi_srd, axi_busy, axi_err : std_logic;
  signal sb_dev, sb_wd, sb_rd : std_logic_vector(7 downto 0); signal sb_reg : std_logic_vector(15 downto 0);
  signal sb_swr, sb_srd, sb_busy, sb_nack : std_logic;
  signal f_start, f_cam, f_dsi, f_ack : std_logic; signal f_state : std_logic_vector(2 downto 0);
  signal pwdn, crst, cap_en, stream_en, led_err : std_logic;
  signal ovf_p, und_v, ovf_c, und_c, clr_c, fault, fifo_rst_n : std_logic;
  signal err_code : std_logic_vector(7 downto 0);
  -- chemin video
  signal we, full, empty, re : std_logic; signal wd18, rd18 : std_logic_vector(17 downto 0);
  signal wrst_n, rrst_n : std_logic; signal lvl : unsigned(FIFO_AW downto 0);
begin
  u_rst  : entity work.sync_bit port map (clk, rst_n, rst_c);
  u_rstv : entity work.sync_bit port map (clk_vid, rst_n, rstv_n);
  u_rstp : entity work.sync_bit port map (cam_pclk, rst_n, rstp_n);

  -- base de temps 1 ms
  process (clk) begin
    if rising_edge(clk) then
      if rst_c = '0' then tcnt <= 0; ms_cnt <= (others => '0'); tick <= '0';
      elsif tcnt = CLK_HZ/1000 - 1 then tcnt <= 0; tick <= '1'; ms_cnt <= ms_cnt + 1;
      else tcnt <= tcnt + 1; tick <= '0'; end if;
    end if;
  end process;

  u_cpu : entity work.pb_ctrl generic map (AW)
    port map (clk, rst_c, axi_addr, axi_wd, axi_swr, axi_srd, axi_rd, axi_busy, axi_err,
              sb_dev, sb_reg, sb_wd, sb_swr, sb_srd, sb_rd, sb_busy, sb_nack,
              f_start, f_cam, f_dsi, f_ack, f_state, ovf_c, und_c, clr_c, std_logic_vector(ms_cnt), err_code);

  u_axi : entity work.axil_ctrl generic map (AW)
    port map (clk, rst_c, axi_addr, axi_wd, axi_swr, axi_srd, axi_rd, axi_busy, axi_err,
              m_awaddr, m_awvalid, m_awready, m_wdata, m_wstrb, m_wvalid, m_wready, m_bresp, m_bvalid, m_bready,
              m_araddr, m_arvalid, m_arready, m_rdata, m_rresp, m_rvalid, m_rready);

  u_sccb : entity work.sccb_master generic map (CLK_HZ)
    port map (clk, rst_c, sb_dev, sb_reg, sb_wd, sb_swr, sb_srd, sb_rd, sb_busy, sb_nack,
              cam_sioc, cam_sda_low, cam_sda_in);

  fault <= ovf_c or und_c;
  u_fsm : entity work.cam_disp_fsm generic map (PWR_MS, RST_MS)
    port map (clk, rst_c, tick, f_start, f_cam, f_dsi, fault, f_ack, f_state, pwdn, crst, cap_en, stream_en, led_err);

  process (clk) begin   -- sorties camera registrees
    if rising_edge(clk) then cam_pwdn <= pwdn; cam_rst_n <= crst; end if;
  end process;

  -- FIFO maintenue en reset hors RUN (purge a chaque redemarrage)
  fifo_rst_n <= rst_c and cap_en;
  u_wr : entity work.sync_bit port map (cam_pclk, fifo_rst_n, wrst_n);
  u_rr : entity work.sync_bit port map (clk_vid, fifo_rst_n, rrst_n);

  u_cap : entity work.dvp_capture generic map (FS_RISING)
    port map (cam_pclk, rstp_n, cap_en, cam_vsync, cam_href, cam_d, we, wd18, full, ovf_p, clr_c);
  u_fifo : entity work.async_fifo generic map (18, FIFO_AW)
    port map (cam_pclk, wrst_n, we, wd18, full, clk_vid, rrst_n, re, rd18, empty, lvl);
  u_vid : entity work.vid_out generic map (FIFO_AW, PREFILL)
    port map (clk_vid, rstv_n, stream_en, empty, lvl, rd18, re, m_axis_tdata, m_axis_tvalid, m_axis_tready,
              m_axis_tuser, m_axis_tlast, und_v, clr_c);

  u_so : entity work.sync_bit port map (clk, ovf_p, ovf_c);
  u_su : entity work.sync_bit port map (clk, und_v, und_c);

  status <= err_code(1 downto 0) & led_err & stream_en & cap_en & f_state;
end architecture;

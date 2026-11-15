-- Enveloppe : ajoute le tri-state open-drain de SIOD ; a utiliser comme "module reference" dans un block design
library ieee; use ieee.std_logic_1164.all;
entity cam_disp_top is
  generic (CLK_HZ : integer := 100_000_000; AW : integer := 17);
  port (clk, rst_n : in std_logic;
        cam_pclk, cam_vsync, cam_href : in std_logic; cam_d : in std_logic_vector(7 downto 0);
        cam_sioc : out std_logic; cam_siod : inout std_logic; cam_pwdn, cam_rst_n : out std_logic;
        m_awaddr : out std_logic_vector(AW-1 downto 0); m_awvalid : out std_logic; m_awready : in std_logic;
        m_wdata : out std_logic_vector(31 downto 0); m_wstrb : out std_logic_vector(3 downto 0);
        m_wvalid : out std_logic; m_wready : in std_logic;
        m_bresp : in std_logic_vector(1 downto 0); m_bvalid : in std_logic; m_bready : out std_logic;
        m_araddr : out std_logic_vector(AW-1 downto 0); m_arvalid : out std_logic; m_arready : in std_logic;
        m_rdata : in std_logic_vector(31 downto 0); m_rresp : in std_logic_vector(1 downto 0);
        m_rvalid : in std_logic; m_rready : out std_logic;
        clk_vid : in std_logic;
        m_axis_tdata : out std_logic_vector(23 downto 0); m_axis_tvalid : out std_logic; m_axis_tready : in std_logic;
        m_axis_tuser : out std_logic_vector(0 downto 0); m_axis_tlast : out std_logic;
        status : out std_logic_vector(7 downto 0));
end entity;
architecture rtl of cam_disp_top is
  signal sda_low : std_logic;
begin
  cam_siod <= '0' when sda_low = '1' else 'Z';   -- pull-up externe (ou PULLUP dans le XDC)
  u : entity work.cam_disp_core generic map (CLK_HZ => CLK_HZ, AW => AW)
    port map (clk, rst_n, cam_pclk, cam_vsync, cam_href, cam_d, cam_sioc, sda_low, cam_siod, cam_pwdn, cam_rst_n,
              m_awaddr, m_awvalid, m_awready, m_wdata, m_wstrb, m_wvalid, m_wready, m_bresp, m_bvalid, m_bready,
              m_araddr, m_arvalid, m_arready, m_rdata, m_rresp, m_rvalid, m_rready,
              clk_vid, m_axis_tdata, m_axis_tvalid, m_axis_tready, m_axis_tuser, m_axis_tlast, status);
end architecture;

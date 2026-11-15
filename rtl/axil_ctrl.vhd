-- Maitre AXI4-Lite mono-transaction (ecriture / lecture 32 bits) avec timeout anti-blocage
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity axil_ctrl is
  generic (AW : integer := 17; TO_BITS : integer := 20);
  port (clk, rst_n : in std_logic;
        addr  : in std_logic_vector(AW-1 downto 0);
        wdata : in std_logic_vector(31 downto 0);
        start_wr, start_rd : in std_logic;
        rdata : out std_logic_vector(31 downto 0);
        busy, err : out std_logic;
        m_awaddr : out std_logic_vector(AW-1 downto 0); m_awvalid : out std_logic; m_awready : in std_logic;
        m_wdata  : out std_logic_vector(31 downto 0);   m_wstrb : out std_logic_vector(3 downto 0);
        m_wvalid : out std_logic; m_wready : in std_logic;
        m_bresp  : in std_logic_vector(1 downto 0); m_bvalid : in std_logic; m_bready : out std_logic;
        m_araddr : out std_logic_vector(AW-1 downto 0); m_arvalid : out std_logic; m_arready : in std_logic;
        m_rdata  : in std_logic_vector(31 downto 0); m_rresp : in std_logic_vector(1 downto 0);
        m_rvalid : in std_logic; m_rready : out std_logic);
end entity;
architecture rtl of axil_ctrl is
  type st_t is (IDLE, WR, WRESP, RD, RRESP);
  signal st : st_t := IDLE;
  signal awv, wv, bry, arv, rdy, busy_r, err_r : std_logic := '0';
  signal to_cnt : unsigned(TO_BITS-1 downto 0) := (others => '0');
  signal awa : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal wd, rd_r : std_logic_vector(31 downto 0) := (others => '0');
begin
  m_awaddr <= awa; m_araddr <= awa; m_wdata <= wd; m_wstrb <= "1111";
  m_awvalid <= awv; m_wvalid <= wv; m_bready <= bry; m_arvalid <= arv; m_rready <= rdy;
  busy <= busy_r; err <= err_r; rdata <= rd_r;
  process (clk)
    variable aw_ok, w_ok : boolean;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        st <= IDLE; awv <= '0'; wv <= '0'; bry <= '0'; arv <= '0'; rdy <= '0'; busy_r <= '0'; err_r <= '0';
      else
        if st /= IDLE then to_cnt <= to_cnt + 1; else to_cnt <= (others => '0'); end if;
        case st is
          when IDLE =>
            if start_wr = '1' then
              awa <= addr; wd <= wdata; awv <= '1'; wv <= '1'; busy_r <= '1'; err_r <= '0'; st <= WR;
            elsif start_rd = '1' then
              awa <= addr; arv <= '1'; busy_r <= '1'; err_r <= '0'; st <= RD;
            end if;
          when WR =>
            aw_ok := (awv = '0') or (m_awready = '1');
            w_ok  := (wv = '0')  or (m_wready = '1');
            if awv = '1' and m_awready = '1' then awv <= '0'; end if;
            if wv  = '1' and m_wready  = '1' then wv  <= '0'; end if;
            if aw_ok and w_ok then bry <= '1'; st <= WRESP; end if;
          when WRESP =>
            if m_bvalid = '1' then bry <= '0'; err_r <= m_bresp(1); busy_r <= '0'; st <= IDLE; end if;
          when RD =>
            if m_arready = '1' then arv <= '0'; rdy <= '1'; st <= RRESP; end if;
          when RRESP =>
            if m_rvalid = '1' then rd_r <= m_rdata; err_r <= m_rresp(1); rdy <= '0'; busy_r <= '0'; st <= IDLE; end if;
        end case;
        if st /= IDLE and to_cnt = (to_cnt'range => '1') then   -- timeout
          awv <= '0'; wv <= '0'; bry <= '0'; arv <= '0'; rdy <= '0'; err_r <= '1'; busy_r <= '0'; st <= IDLE;
        end if;
      end if;
    end if;
  end process;
end architecture;

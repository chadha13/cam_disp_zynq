-- Cote video (PREFILL = nb de mots a accumuler avant de demarrer le flux : absorbe la phase camera/DSI)
-- Cote video (domaine clk_vid) : FIFO -> AXI4-Stream RGB888 (tuser(0)=SOF, tlast=EOL) + detection underrun
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity vid_out is
  generic (AW : positive := 10; PREFILL : natural := 256);
  port (clk, rst_n, stream_en : in std_logic;
        f_empty : in std_logic; level : in unsigned(AW downto 0); f_rdata : in std_logic_vector(17 downto 0); f_re : out std_logic;
        tdata : out std_logic_vector(23 downto 0); tvalid : out std_logic; tready : in std_logic;
        tuser : out std_logic_vector(0 downto 0); tlast : out std_logic;
        underrun : out std_logic; clr : in std_logic);
end entity;
architecture rtl of vid_out is
  signal armed, und, en_s, clr_s, tv, started : std_logic := '0';
  signal p : std_logic_vector(15 downto 0); signal pf_ok : std_logic;
begin
  u_e : entity work.sync_bit port map (clk, stream_en, en_s);
  u_c : entity work.sync_bit port map (clk, clr, clr_s);
  p <= f_rdata(15 downto 0);
  pf_ok <= '1' when level >= PREFILL else '0';
  tv <= en_s and not f_empty and (started or pf_ok);
  tvalid <= tv; f_re <= tv and tready;
  tdata <= p(15 downto 11) & p(15 downto 13) & p(10 downto 5) & p(10 downto 9) & p(4 downto 0) & p(4 downto 2);
  tuser(0) <= f_rdata(16); tlast <= f_rdata(17);
  underrun <= und;
  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' or en_s = '0' then started <= '0'; elsif level >= PREFILL then started <= '1'; end if;
      if rst_n = '0' or en_s = '0' then armed <= '0';
      elsif tv = '1' and tready = '1' and f_rdata(16) = '1' then armed <= '1'; end if;
      if rst_n = '0' or clr_s = '1' then und <= '0'; end if;
      if rst_n = '1' and en_s = '1' and tready = '1' and f_empty = '1' and armed = '1' then und <= '1'; end if;
    end if;
  end process;
end architecture;

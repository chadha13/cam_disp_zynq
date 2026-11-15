-- FIFO asynchrone (pointeurs Gray, drapeaux full/empty registres). Lecture asynchrone (LUTRAM) -> FWFT
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity async_fifo is
  generic (W : positive := 18; AW : positive := 10);
  port (wclk, wrst_n, we : in std_logic; wdata : in std_logic_vector(W-1 downto 0); full : out std_logic;
        rclk, rrst_n, re : in std_logic; rdata : out std_logic_vector(W-1 downto 0); empty : out std_logic;
        rlevel : out unsigned(AW downto 0));
end entity;
architecture rtl of async_fifo is
  type ram_t is array (0 to 2**AW-1) of std_logic_vector(W-1 downto 0);
  signal ram : ram_t;
  signal wbin, wgray, rbin, rgray : unsigned(AW downto 0) := (others => '0');
  signal rg_w1, rg_w2, wg_r1, wg_r2 : unsigned(AW downto 0) := (others => '0');
  signal full_r : std_logic := '0'; signal empty_r : std_logic := '1';
  attribute async_reg : string;
  attribute async_reg of rg_w1, rg_w2, wg_r1, wg_r2 : signal is "true";
  signal lvl : unsigned(AW downto 0) := (others => '0');
  function gray(b : unsigned) return unsigned is begin return b xor ('0' & b(b'left downto 1)); end function;
  function g2b(g : unsigned) return unsigned is variable b : unsigned(g'range); begin
    b(b'left) := g(g'left);
    for i in g'left - 1 downto 0 loop b(i) := b(i + 1) xor g(i); end loop; return b; end function;
begin
  full <= full_r; empty <= empty_r; rlevel <= lvl;
  rdata <= ram(to_integer(rbin(AW-1 downto 0)));

  process (wclk)
    variable nb, ng : unsigned(AW downto 0);
  begin
    if rising_edge(wclk) then
      if wrst_n = '0' then
        wbin <= (others => '0'); wgray <= (others => '0'); full_r <= '0'; rg_w1 <= (others => '0'); rg_w2 <= (others => '0');
      else
        rg_w1 <= rgray; rg_w2 <= rg_w1;
        nb := wbin;
        if we = '1' and full_r = '0' then ram(to_integer(wbin(AW-1 downto 0))) <= wdata; nb := wbin + 1; end if;
        ng := gray(nb);
        wbin <= nb; wgray <= ng;
        if ng = (not rg_w2(AW downto AW-1)) & rg_w2(AW-2 downto 0) then full_r <= '1'; else full_r <= '0'; end if;
      end if;
    end if;
  end process;

  process (rclk)
    variable nb, ng : unsigned(AW downto 0);
  begin
    if rising_edge(rclk) then
      if rrst_n = '0' then
        rbin <= (others => '0'); rgray <= (others => '0'); empty_r <= '1'; lvl <= (others => '0'); wg_r1 <= (others => '0'); wg_r2 <= (others => '0');
      else
        wg_r1 <= wgray; wg_r2 <= wg_r1;
        nb := rbin;
        if re = '1' and empty_r = '0' then nb := rbin + 1; end if;
        ng := gray(nb);
        rbin <= nb; rgray <= ng;
        if ng = wg_r2 then empty_r <= '1'; else empty_r <= '0'; end if;
        lvl <= g2b(wg_r2) - nb;   -- niveau (pessimiste : pointeur d'ecriture synchronise)
      end if;
    end if;
  end process;
end architecture;

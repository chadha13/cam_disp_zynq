-- SCCB : ecriture 0x3008<=0x82 et lecture 0x300A (esclave simule : repond 0x56, ACK sur chaque octet)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity tb_sccb is generic (DO_READ : boolean := false); end entity;
architecture tb of tb_sccb is
  signal clk : std_logic := '0'; signal rst_n : std_logic := '0';
  signal swr, srd, busy, nack, sioc, sda_low, sda_in, slv_low : std_logic := '0';
  signal rdata : std_logic_vector(7 downto 0);
  signal is_read : boolean := DO_READ; signal done : boolean := false;
  signal s_dev, s_rh, s_rl, s_wd : std_logic_vector(7 downto 0) := (others => '0');
begin
  clk <= not clk after 5 ns when not done;
  sda_in <= '0' when (sda_low = '1' or slv_low = '1') else '1';
  dut : entity work.sccb_master generic map (CLK_HZ => 100_000_000, SCCB_HZ => 1_000_000)
    port map (clk, rst_n, x"78", x"300A", x"82", swr, srd, rdata, busy, nack, sioc, sda_low, sda_in);

  slave : process
    variable b : std_logic_vector(7 downto 0);
    procedure rx(variable r : out std_logic_vector(7 downto 0)) is begin
      for i in 0 to 7 loop wait until rising_edge(sioc); r := r(6 downto 0) & sda_in; end loop;
      wait until falling_edge(sioc); slv_low <= '1'; wait until falling_edge(sioc); slv_low <= '0';
    end procedure;
  begin
    wait until sda_in = '0' and sioc = '1';                          -- START
    rx(b); s_dev <= b; rx(b); s_rh <= b; rx(b); s_rl <= b;
    if not is_read then rx(b); s_wd <= b;
    else
      wait until sda_in = '1' and sioc = '1';                        -- STOP
      wait until sda_in = '0' and sioc = '1';                        -- repeated START
      rx(b); s_dev <= b;
      b := x"56";
      for i in 7 downto 0 loop slv_low <= not b(i); wait until falling_edge(sioc); end loop;
      slv_low <= '0';
    end if;
    wait;
  end process;

  process
    procedure clks(n : integer) is begin for i in 1 to n loop wait until rising_edge(clk); end loop; end procedure;
  begin
    clks(5); rst_n <= '1'; clks(5);
    if DO_READ then srd <= '1'; clks(1); srd <= '0'; else swr <= '1'; clks(1); swr <= '0'; end if;
    clks(2);
    wait until busy = '0' for 400 us; clks(5);
    if DO_READ then
      assert s_dev = x"79" and s_rh = x"30" and s_rl = x"0A" and rdata = x"56"
        report "ECHEC lecture : dev=" & to_hstring(s_dev) & " rdata=" & to_hstring(rdata) severity error;
      if s_dev = x"79" and s_rh = x"30" and s_rl = x"0A" and rdata = x"56" then
        report "TB_SCCB_READ_PASS : ID 0x56 lu a 300A"; end if;
      done <= true; wait;
    end if;
    assert s_dev = x"78" and s_rh = x"30" and s_rl = x"0A" and s_wd = x"82"
      report "ECHEC ecriture : recu " & to_hstring(s_dev) & " " & to_hstring(s_rh) & to_hstring(s_rl) & " " & to_hstring(s_wd) severity error;
    assert nack = '0' report "ECHEC: NACK inattendu en ecriture" severity error;
    if s_dev = x"78" and s_rh = x"30" and s_rl = x"0A" and s_wd = x"82" and nack = '0' then
      report "TB_SCCB_WRITE_PASS : 78 / 300A / 82"; end if;
    done <= true; wait;
  end process;
end architecture;

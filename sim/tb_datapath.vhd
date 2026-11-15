-- DVP -> dvp_capture -> async_fifo -> vid_out ; trame 6x3 pixels RGB565
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity tb_datapath is end entity;
architecture tb of tb_datapath is
  signal pclk, cvid : std_logic := '0'; signal rst_n, cap_en, stream_en, clr : std_logic := '0';
  signal vsync : std_logic := '1'; signal href : std_logic := '0'; signal d : std_logic_vector(7 downto 0) := (others => '0');
  signal we, full, empty, re, ovf, und, tvalid, tready, tlast : std_logic;
  signal tuser : std_logic_vector(0 downto 0); signal tdata : std_logic_vector(23 downto 0);
  signal wd, rd : std_logic_vector(17 downto 0); signal lvl : unsigned(6 downto 0); signal rdy_mode : integer := 0; signal rc : integer := 0; signal frst_n : std_logic := '0';
  signal npix, nsof, neol : integer := 0; signal first_data : std_logic_vector(23 downto 0) := (others => '0');
  signal got_first : boolean := false; signal sof_ok : boolean := true;
  signal done : boolean := false;
  type pix_t is array (0 to 17) of std_logic_vector(15 downto 0);
  signal exp_pix : pix_t; signal mism : integer := 0;
  function exp24(p : std_logic_vector(15 downto 0)) return std_logic_vector is begin
    return p(15 downto 11) & p(15 downto 13) & p(10 downto 5) & p(10 downto 9) & p(4 downto 0) & p(4 downto 2); end function;
begin
  pclk <= not pclk after 20 ns when not done;
  cvid <= not cvid after 10 ns when not done;
  u_c : entity work.dvp_capture port map (pclk, rst_n, cap_en, vsync, href, d, we, wd, full, ovf, clr);
  u_f : entity work.async_fifo generic map (18, 6) port map (pclk, frst_n, we, wd, full, cvid, frst_n, re, rd, empty, lvl);
  u_v : entity work.vid_out generic map (6, 6) port map (cvid, rst_n, stream_en, empty, lvl, rd, re, tdata, tvalid, tready, tuser, tlast, und, clr);

  -- tready realiste : 1 cycle sur 5 (plus lent que la camera). mode 0 = trame en cours (coupe apres 18 px), 1 = force (underrun), 2 = coupe
  process (cvid) begin
    if rising_edge(cvid) then
      if rc = 4 then rc <= 0; else rc <= rc + 1; end if;
      if rc = 0 and ((rdy_mode = 0 and npix < 18) or rdy_mode = 1) then tready <= '1'; else tready <= '0'; end if;
    end if;
  end process;

  -- moniteur AXIS
  process (cvid) begin
    if rising_edge(cvid) and tvalid = '1' and tready = '1' then
      if npix < 18 and tdata /= exp24(exp_pix(npix)) then mism <= mism + 1; end if;
      if tuser(0) = '1' then nsof <= nsof + 1; if npix /= 0 then sof_ok <= false; end if; end if;
      if tlast = '1' then neol <= neol + 1; if (npix + 1) mod 6 /= 0 then sof_ok <= false; end if; end if;
      npix <= npix + 1;
    end if;
  end process;

  process
    variable k : integer := 0;
    variable p : std_logic_vector(15 downto 0);
    procedure pclks(n : integer) is begin for i in 1 to n loop wait until rising_edge(pclk); end loop; end procedure;
  begin
    for i in 0 to 17 loop exp_pix(i) <= std_logic_vector(to_unsigned((16#F800# + i * 16#0841#) mod 65536, 16)); end loop;
    wait for 1 ns;
    pclks(3); rst_n <= '1';
    -- demarrage RUN : FIFO sort de reset, capture et flux actifs
    pclks(3); frst_n <= '1'; cap_en <= '1'; stream_en <= '1'; pclks(4);
    -- fin de trame precedente (VSYNC haut), puis front descendant = debut de trame
    vsync <= '1'; pclks(6); vsync <= '0'; pclks(5);
    for l in 0 to 2 loop
      href <= '1';
      for x in 0 to 5 loop
        p := exp_pix(l * 6 + x);
        d <= p(15 downto 8); pclks(1); d <= p(7 downto 0); pclks(1);
      end loop;
      href <= '0'; d <= x"00"; pclks(6);
    end loop;
    vsync <= '1'; pclks(30);
    assert npix = 18 report "ECHEC: 18 pixels attendus, recus " & integer'image(npix) severity error;
    assert nsof = 1 report "ECHEC: 1 SOF attendu" severity error;
    assert neol = 3 report "ECHEC: 3 EOL attendus, recus " & integer'image(neol) severity error;
    assert mism = 0 report "ECHEC: donnees pixel RGB565->RGB888 incorrectes" severity error;
    assert sof_ok report "ECHEC: positions SOF/EOL" severity error;
    assert ovf = '0' report "ECHEC: overflow inattendu" severity error;
    assert und = '0' report "ECHEC: underrun inattendu" severity error;
    if npix = 18 and nsof = 1 and neol = 3 and mism = 0 and sof_ok and ovf = '0' and und = '0' then
      report "TB_DATAPATH_PASS : 18 pixels, SOF x1, EOL x3, RGB888 exact"; end if;

    -- Test underrun : 8 pixels (>= PREFILL) puis la camera s'arrete alors que le DSI continue a demander
    rdy_mode <= 1; vsync <= '1'; pclks(4); vsync <= '0'; pclks(3);
    href <= '1'; for x in 0 to 7 loop d <= x"12"; pclks(1); d <= x"34"; pclks(1); end loop; href <= '0'; pclks(60);
    assert und = '1' report "ECHEC: underrun non detecte" severity error;
    if und = '1' then report "TB_UNDERRUN_PASS : underrun detecte"; end if;
    rdy_mode <= 2; pclks(10); clr <= '1'; pclks(6); clr <= '0'; pclks(2);
    assert und = '0' report "ECHEC: effacement underrun" severity error;
    if und = '0' then report "TB_CLEAR_PASS : drapeau efface"; end if;

    -- Test overflow : FIFO 64 mots, flux coupe (stream_en=0) -> ecriture sans lecture
    stream_en <= '0'; pclks(4); frst_n <= '0'; pclks(4); frst_n <= '1'; pclks(2);
    vsync <= '1'; pclks(4); vsync <= '0'; pclks(3);
    for l in 0 to 5 loop
      href <= '1'; for x in 0 to 29 loop d <= x"A5"; pclks(1); d <= x"5A"; pclks(1); end loop;
      href <= '0'; pclks(4);
    end loop;
    pclks(10);
    assert ovf = '1' report "ECHEC: overflow non detecte" severity error;
    if ovf = '1' then report "TB_OVERFLOW_PASS : overflow detecte"; end if;
    done <= true; wait;
  end process;
end architecture;

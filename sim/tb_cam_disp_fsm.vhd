library ieee; use ieee.std_logic_1164.all;
entity tb_cam_disp_fsm is end entity;
architecture tb of tb_cam_disp_fsm is
  signal clk : std_logic := '0'; signal rst_n : std_logic := '0';
  signal tick, start, cam_done, dsi_done, fault, ack : std_logic := '0';
  signal st : std_logic_vector(2 downto 0);
  signal pwdn, crst, cap, strm, led : std_logic;
  signal tcnt : integer := 0; shared variable ok : integer := 0; signal done : boolean := false;
  procedure chk(c : boolean; msg : string) is begin
    assert c report "ECHEC: " & msg severity error; if c then ok := ok + 1; end if; end procedure;
begin
  clk <= not clk after 5 ns when not done;
  process (clk) begin  -- tick 1 ms = 10 cycles
    if rising_edge(clk) then if tcnt = 9 then tcnt <= 0; tick <= '1'; else tcnt <= tcnt + 1; tick <= '0'; end if; end if;
  end process;
  dut : entity work.cam_disp_fsm generic map (2, 3)
    port map (clk, rst_n, tick, start, cam_done, dsi_done, fault, ack, st, pwdn, crst, cap, strm, led);
  process
    variable n : integer := 0;
    procedure waitst(code : std_logic_vector(2 downto 0); maxc : integer) is variable i : integer := 0; begin
      while st /= code and i < maxc loop wait until rising_edge(clk); i := i + 1; end loop; end procedure;
  begin
    -- 1 reset -> IDLE, camera en power-down
    wait for 23 ns; rst_n <= '1'; wait until rising_edge(clk); wait for 1 ns;
    chk(st = "000" and crst = '0' and cap = '0' and strm = '0', "1 IDLE apres reset");
    -- Mealy : start=0 en IDLE => pwdn=1 ; start=1 => pwdn=0 dans le meme cycle (sans changer d'etat)
    chk(pwdn = '1', "2a pwdn=1 en IDLE start=0");
    start <= '1'; wait for 1 ns;
    chk(st = "000" and pwdn = '0', "2b Mealy : pwdn tombe avec l'entree start (meme cycle)");
    -- 3 sequence d'alimentation puis reset : POWER -> RESET -> CFG_CAM
    waitst("001", 5); wait for 1 ns; chk(st = "001" and crst = '0', "3a POWER reset maintenu");
    waitst("010", 100); wait for 1 ns; chk(st = "010" and crst = '1', "3b RESET : rst_n capteur relache");
    waitst("011", 100); wait for 1 ns; chk(st = "011", "3c CFG_CAM atteint apres RST_MS");
    -- 4 pas de passage sans acquittement firmware
    wait for 100 ns; chk(st = "011" and cap = '0', "4 reste en CFG_CAM sans cam_done");
    cam_done <= '1'; waitst("100", 5); wait for 1 ns; chk(st = "100", "4b CFG_DSI apres cam_done");
    dsi_done <= '1'; waitst("101", 5); wait for 1 ns;
    chk(st = "101" and cap = '1' and strm = '1', "5 RUN : capture + flux actifs");
    -- 6 Mealy : defaut => stream_en/cap_en tombent AU MEME CYCLE que l'entree fault
    fault <= '1'; wait for 1 ns;
    chk(st = "101" and strm = '0' and cap = '0' and led = '1', "6a Mealy : flux coupe immediatement sur fault");
    wait until rising_edge(clk); wait for 1 ns; chk(st = "110", "6b etat FAULT");
    -- 7 acquittement : retour en CFG_CAM (reconfiguration complete)
    fault <= '0'; cam_done <= '0'; dsi_done <= '0'; ack <= '1';
    wait until rising_edge(clk); wait for 1 ns; ack <= '0'; chk(st = "011", "7a FAULT -> CFG_CAM sur ack");
    cam_done <= '1'; waitst("100", 5); dsi_done <= '1'; waitst("101", 5); wait for 1 ns;
    chk(st = "101" and strm = '1', "7b reprise en RUN");
    -- 8 abandon : start=0 depuis RUN -> IDLE
    start <= '0'; wait for 1 ns; chk(strm = '0' and cap = '0' and crst = '0', "8a Mealy : sorties coupees avec start=0");
    wait until rising_edge(clk); wait for 1 ns; chk(st = "000", "8b retour IDLE");
    report "FSM : " & integer'image(ok) & " verifications OK (15 attendues)";
    assert ok = 15 report "FSM : NOMBRE DE VERIFICATIONS INATTENDU" severity failure;
    report "TB_FSM_PASS"; done <= true; wait;
  end process;
end architecture;

-- PicoBlaze (KCPSM6) + decodage de ports. Plan d'adressage : voir docs/PORTS.md
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity pb_ctrl is
  generic (AW : integer := 17);
  port (clk, rst_n : in std_logic;
        -- pont AXI4-Lite
        axi_addr : out std_logic_vector(AW-1 downto 0); axi_wdata : out std_logic_vector(31 downto 0);
        axi_start_wr, axi_start_rd : out std_logic;
        axi_rdata : in std_logic_vector(31 downto 0); axi_busy, axi_err : in std_logic;
        -- SCCB
        sb_dev : out std_logic_vector(7 downto 0); sb_reg : out std_logic_vector(15 downto 0);
        sb_wdata : out std_logic_vector(7 downto 0); sb_start_wr, sb_start_rd : out std_logic;
        sb_rdata : in std_logic_vector(7 downto 0); sb_busy, sb_nack : in std_logic;
        -- FSM / drapeaux
        fsm_start, fsm_cam_done, fsm_dsi_done, fsm_ack : out std_logic;
        fsm_state : in std_logic_vector(2 downto 0);
        flag_ovf, flag_und : in std_logic; flag_clr : out std_logic;
        ms_cnt : in std_logic_vector(7 downto 0);
        err_code : out std_logic_vector(7 downto 0));
end entity;

architecture rtl of pb_ctrl is
  component kcpsm6 is
    generic (hwbuild : std_logic_vector(7 downto 0) := X"00";
             interrupt_vector : std_logic_vector(11 downto 0) := X"3FF";
             scratch_pad_memory_size : integer := 64);
    port (address : out std_logic_vector(11 downto 0); instruction : in std_logic_vector(17 downto 0);
          bram_enable : out std_logic; in_port : in std_logic_vector(7 downto 0);
          out_port : out std_logic_vector(7 downto 0); port_id : out std_logic_vector(7 downto 0);
          write_strobe, k_write_strobe, read_strobe : out std_logic;
          interrupt : in std_logic; interrupt_ack : out std_logic;
          sleep : in std_logic; reset : in std_logic; clk : in std_logic);
  end component;
  component cam_disp is   -- ROM generee par l'assembleur officiel kcpsm6 (ROM_form.vhd)
    generic (C_FAMILY : string := "7S"; C_RAM_SIZE_KWORDS : integer := 1; C_JTAG_LOADER_ENABLE : integer := 0);
    port (address : in std_logic_vector(11 downto 0); instruction : out std_logic_vector(17 downto 0);
          enable : in std_logic; rdl : out std_logic; clk : in std_logic);
  end component;

  signal address : std_logic_vector(11 downto 0);
  signal instruction : std_logic_vector(17 downto 0);
  signal bram_enable, rdl, kreset : std_logic;
  signal in_port, out_port, port_id : std_logic_vector(7 downto 0) := (others => '0');
  signal wr_s, kwr_s, rd_s : std_logic;

  signal wd : std_logic_vector(31 downto 0) := (others => '0');
  signal ad : std_logic_vector(23 downto 0) := (others => '0');
  signal sb_rh, sb_rl, sb_wd, sb_dv : std_logic_vector(7 downto 0) := (others => '0');
  signal fsmc : std_logic_vector(7 downto 0) := (others => '0');
  signal clr_r : std_logic := '0';
  signal err_r : std_logic_vector(7 downto 0) := (others => '0');
  signal axp_wr, axp_rd, sbp_wr, sbp_rd : std_logic := '0';
begin
  kreset <= rdl or (not rst_n);
  u_cpu : kcpsm6
    port map (address => address, instruction => instruction, bram_enable => bram_enable,
              in_port => in_port, out_port => out_port, port_id => port_id,
              write_strobe => wr_s, k_write_strobe => kwr_s, read_strobe => rd_s,
              interrupt => '0', interrupt_ack => open, sleep => '0', reset => kreset, clk => clk);
  u_rom : cam_disp
    port map (address => address, instruction => instruction, enable => bram_enable, rdl => rdl, clk => clk);

  axi_wdata <= wd; axi_addr <= ad(AW-1 downto 0);
  axi_start_wr <= axp_wr; axi_start_rd <= axp_rd;
  sb_dev <= sb_dv; sb_reg <= sb_rh & sb_rl; sb_wdata <= sb_wd; sb_start_wr <= sbp_wr; sb_start_rd <= sbp_rd;
  fsm_start <= fsmc(0); fsm_cam_done <= fsmc(1); fsm_dsi_done <= fsmc(2); fsm_ack <= fsmc(3);
  flag_clr <= clr_r; err_code <= err_r;

  process (clk) begin
    if rising_edge(clk) then
      axp_wr <= '0'; axp_rd <= '0'; sbp_wr <= '0'; sbp_rd <= '0';
      if rst_n = '0' then
        fsmc <= (others => '0'); clr_r <= '0'; err_r <= (others => '0'); sb_dv <= x"78";
      elsif wr_s = '1' then
        case port_id is
          when x"10" => wd(7 downto 0)   <= out_port;
          when x"11" => wd(15 downto 8)  <= out_port;
          when x"12" => wd(23 downto 16) <= out_port;
          when x"13" => wd(31 downto 24) <= out_port;
          when x"14" => ad(7 downto 0)   <= out_port;
          when x"15" => ad(15 downto 8)  <= out_port;
          when x"16" => ad(23 downto 16) <= out_port;
          when x"17" => axp_wr <= out_port(0); axp_rd <= out_port(1);
          when x"20" => sb_rh <= out_port;
          when x"21" => sb_rl <= out_port;
          when x"22" => sb_wd <= out_port;
          when x"23" => sbp_wr <= out_port(0); sbp_rd <= out_port(1);
          when x"30" => clr_r <= out_port(0);
          when x"34" => fsmc <= out_port;
          when x"35" => sb_dv <= out_port;
          when x"3A" => err_r <= out_port;
          when others => null;
        end case;
      end if;
      -- lecture (valide au cycle du read_strobe + 1, conforme au protocole KCPSM6)
      case port_id is
        when x"18" => in_port <= axi_rdata(7 downto 0);
        when x"19" => in_port <= axi_rdata(15 downto 8);
        when x"1A" => in_port <= axi_rdata(23 downto 16);
        when x"1B" => in_port <= axi_rdata(31 downto 24);
        when x"1C" => in_port <= "000000" & axi_err & (axi_busy or axp_wr or axp_rd);
        when x"24" => in_port <= sb_rdata;
        when x"25" => in_port <= "000000" & sb_nack & (sb_busy or sbp_wr or sbp_rd);
        when x"31" => in_port <= "000000" & flag_und & flag_ovf;
        when x"33" => in_port <= "00000" & fsm_state;
        when x"39" => in_port <= ms_cnt;
        when others => in_port <= (others => '0');
      end case;
    end if;
  end process;
end architecture;

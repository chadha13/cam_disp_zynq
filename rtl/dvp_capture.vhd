-- Capture DVP 8 bits (RGB565 : octet haut puis octet bas) -> mots 18 bits {eol, sof, pixel16}
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity dvp_capture is
  generic (FS_RISING : boolean := false);  -- debut de trame sur front montant (true) ou descendant (false) de VSYNC
  port (pclk, rst_n, cap_en : in std_logic;
        vsync, href : in std_logic; d : in std_logic_vector(7 downto 0);
        we : out std_logic; wdata : out std_logic_vector(17 downto 0);
        full : in std_logic; ovf : out std_logic; clr : in std_logic);
end entity;
architecture rtl of dvp_capture is
  signal vs_d, hs_d, in_frame, first, phase, hold_v, hold_sof : std_logic := '0';
  signal hi : std_logic_vector(7 downto 0) := (others => '0');
  signal hold_pix : std_logic_vector(15 downto 0) := (others => '0');
  signal cap_s, clr_s, we_r, ovf_r : std_logic := '0';
  signal wd_r : std_logic_vector(17 downto 0) := (others => '0');
begin
  u_c : entity work.sync_bit port map (pclk, cap_en, cap_s);
  u_k : entity work.sync_bit port map (pclk, clr, clr_s);
  we <= we_r; wdata <= wd_r; ovf <= ovf_r;
  process (pclk)
    variable fs : boolean;
  begin
    if rising_edge(pclk) then
      if rst_n = '0' then
        in_frame <= '0'; we_r <= '0'; ovf_r <= '0'; hold_v <= '0'; phase <= '0'; first <= '0';
      else
        vs_d <= vsync; hs_d <= href; we_r <= '0';
        if FS_RISING then fs := (vsync = '1' and vs_d = '0'); else fs := (vsync = '0' and vs_d = '1'); end if;
        if clr_s = '1' then ovf_r <= '0'; end if;
        if we_r = '1' and full = '1' then ovf_r <= '1'; end if;
        if cap_s = '0' then in_frame <= '0';
        elsif fs then in_frame <= '1'; first <= '1'; phase <= '0'; hold_v <= '0'; end if;
        if in_frame = '1' and not fs then
          if href = '1' then
            if phase = '0' then hi <= d; phase <= '1';
            else
              phase <= '0';
              if hold_v = '1' then we_r <= '1'; wd_r <= '0' & hold_sof & hold_pix; end if;
              hold_pix <= hi & d; hold_sof <= first; first <= '0'; hold_v <= '1';
            end if;
          elsif hs_d = '1' then               -- fin de ligne : on emet le dernier pixel avec EOL
            phase <= '0';
            if hold_v = '1' then we_r <= '1'; wd_r <= '1' & hold_sof & hold_pix; hold_v <= '0'; end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;

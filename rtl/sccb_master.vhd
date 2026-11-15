-- Maitre SCCB (I2C-like, adresse registre 16 bits, ex. OV5640). ACK 9e bit = "don't care" (nack informatif)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity sccb_master is
  generic (CLK_HZ : integer := 100_000_000; SCCB_HZ : integer := 100_000);
  port (clk, rst_n : in std_logic;
        dev_wr_addr : in std_logic_vector(7 downto 0);   -- ex. x"78"
        reg_addr    : in std_logic_vector(15 downto 0);
        wdata       : in std_logic_vector(7 downto 0);
        start_wr, start_rd : in std_logic;               -- impulsions
        rdata       : out std_logic_vector(7 downto 0);
        busy, nack  : out std_logic;
        sioc        : out std_logic;
        sda_low     : out std_logic;                     -- 1 = tire SDA a 0 (open-drain)
        sda_in      : in std_logic);
end entity;
architecture rtl of sccb_master is
  constant DIV : integer := CLK_HZ / (4 * SCCB_HZ);
  signal dcnt : integer range 0 to DIV := 0;
  signal tick, sda_s : std_logic;
  signal run, is_rd, nack_r : std_logic := '0';
  signal step : integer range 0 to 15 := 0;
  signal ph   : integer range 0 to 3 := 0;
  signal bitn : integer range 0 to 8 := 0;
  signal sh, rsh : std_logic_vector(7 downto 0) := (others => '0');
  signal rd_r : std_logic_vector(7 downto 0) := (others => '0');
  signal sioc_r : std_logic := '1'; signal sdal_r : std_logic := '0';
  -- type d'etape: 0 START, 1 OUT, 2 IN, 3 STOP, 4 FIN
  function kind(rd : std_logic; s : integer) return integer is begin
    if rd = '0' then
      case s is when 0 => return 0; when 1 | 2 | 3 | 4 => return 1; when 5 => return 3; when others => return 4; end case;
    else
      case s is when 0 | 5 => return 0; when 1 | 2 | 3 | 6 => return 1; when 4 | 8 => return 3; when 7 => return 2; when others => return 4; end case;
    end if;
  end function;
begin
  u_s : entity work.sync_bit generic map ('1') port map (clk, sda_in, sda_s);
  sioc <= sioc_r; sda_low <= sdal_r; busy <= run; nack <= nack_r; rdata <= rd_r;

  process (clk) begin
    if rising_edge(clk) then
      if dcnt = DIV - 1 then dcnt <= 0; tick <= '1'; else dcnt <= dcnt + 1; tick <= '0'; end if;
    end if;
  end process;

  process (clk)
    variable k : integer;
    variable nxt : boolean;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        run <= '0'; sioc_r <= '1'; sdal_r <= '0'; nack_r <= '0'; step <= 0; ph <= 0; bitn <= 0;
      elsif run = '0' then
        if start_wr = '1' or start_rd = '1' then
          run <= '1'; is_rd <= start_rd; step <= 0; ph <= 0; bitn <= 0; nack_r <= '0';
        end if;
      elsif tick = '1' then
        k := kind(is_rd, step); nxt := false;
        case k is
          when 0 => -- START
            case ph is
              when 0 => sioc_r <= '1'; sdal_r <= '0'; ph <= 1;
              when 1 => sdal_r <= '1'; ph <= 2;
              when others => sioc_r <= '0'; nxt := true;
            end case;
            -- octet a emettre selon l'etape suivante
          when 1 => -- OUT (8 bits + slot ACK)
            case ph is
              when 0 => sioc_r <= '0'; if bitn < 8 then sdal_r <= not sh(7); else sdal_r <= '0'; end if; ph <= 1;
              when 1 => sioc_r <= '1'; ph <= 2;
              when 2 => if bitn = 8 then nack_r <= nack_r or sda_s; end if; ph <= 3;
              when others =>
                sioc_r <= '0'; sh <= sh(6 downto 0) & '0'; ph <= 0;
                if bitn = 8 then bitn <= 0; nxt := true; else bitn <= bitn + 1; end if;
            end case;
          when 2 => -- IN (8 bits + NACK maitre)
            case ph is
              when 0 => sioc_r <= '0'; sdal_r <= '0'; ph <= 1;
              when 1 => sioc_r <= '1'; ph <= 2;
              when 2 => if bitn < 8 then rsh <= rsh(6 downto 0) & sda_s; end if; ph <= 3;
              when others =>
                sioc_r <= '0'; ph <= 0;
                if bitn = 8 then bitn <= 0; rd_r <= rsh; nxt := true; else bitn <= bitn + 1; end if;
            end case;
          when 3 => -- STOP
            case ph is
              when 0 => sioc_r <= '0'; sdal_r <= '1'; ph <= 1;
              when 1 => sioc_r <= '1'; ph <= 2;
              when others => sdal_r <= '0'; nxt := true;
            end case;
          when others => -- FIN
            run <= '0'; sioc_r <= '1'; sdal_r <= '0';
        end case;
        if nxt then
          ph <= 0; step <= step + 1;
          -- charger l'octet de la prochaine etape OUT
          if is_rd = '0' then
            case step + 1 is
              when 1 => sh <= dev_wr_addr; when 2 => sh <= reg_addr(15 downto 8);
              when 3 => sh <= reg_addr(7 downto 0); when 4 => sh <= wdata; when others => null;
            end case;
          else
            case step + 1 is
              when 1 => sh <= dev_wr_addr; when 2 => sh <= reg_addr(15 downto 8);
              when 3 => sh <= reg_addr(7 downto 0); when 6 => sh <= dev_wr_addr(7 downto 1) & '1';
              when others => null;
            end case;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;

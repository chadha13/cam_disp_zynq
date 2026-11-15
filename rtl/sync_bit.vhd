-- Synchroniseur 2 bascules (passage de domaine d'horloge, 1 bit)
library ieee; use ieee.std_logic_1164.all;
entity sync_bit is
  generic (INIT : std_logic := '0');
  port (clk : in std_logic; d : in std_logic; q : out std_logic);
end entity;
architecture rtl of sync_bit is
  signal s1, s2 : std_logic := INIT;
  attribute async_reg : string;
  attribute async_reg of s1 : signal is "true";
  attribute async_reg of s2 : signal is "true";
begin
  process (clk) begin
    if rising_edge(clk) then s1 <= d; s2 <= s1; end if;
  end process;
  q <= s2;
end architecture;

-- STUB DE SIMULATION UNIQUEMENT : remplace la ROM produite par l'assembleur KCPSM6 (module "cam_disp")
library ieee; use ieee.std_logic_1164.all;
entity cam_disp is
  generic (C_FAMILY : string := "7S"; C_RAM_SIZE_KWORDS : integer := 1; C_JTAG_LOADER_ENABLE : integer := 0);
  port (address : in std_logic_vector(11 downto 0); instruction : out std_logic_vector(17 downto 0);
        enable : in std_logic; rdl : out std_logic; clk : in std_logic);
end entity;
architecture stub of cam_disp is begin instruction <= (others => '0'); rdl <= '0'; end architecture;

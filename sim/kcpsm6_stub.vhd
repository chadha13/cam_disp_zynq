-- STUB DE SIMULATION UNIQUEMENT (permet l'elaboration). Pour la synthese : kcpsm6.vhd officiel Xilinx/AMD.
library ieee; use ieee.std_logic_1164.all;
entity kcpsm6 is
  generic (hwbuild : std_logic_vector(7 downto 0) := X"00"; interrupt_vector : std_logic_vector(11 downto 0) := X"3FF";
           scratch_pad_memory_size : integer := 64);
  port (address : out std_logic_vector(11 downto 0); instruction : in std_logic_vector(17 downto 0);
        bram_enable : out std_logic; in_port : in std_logic_vector(7 downto 0);
        out_port : out std_logic_vector(7 downto 0); port_id : out std_logic_vector(7 downto 0);
        write_strobe, k_write_strobe, read_strobe : out std_logic;
        interrupt : in std_logic; interrupt_ack : out std_logic; sleep : in std_logic; reset : in std_logic; clk : in std_logic);
end entity;
architecture stub of kcpsm6 is begin
  address <= (others => '0'); bram_enable <= '0'; out_port <= (others => '0'); port_id <= (others => '0');
  write_strobe <= '0'; k_write_strobe <= '0'; read_strobe <= '0'; interrupt_ack <= '0';
end architecture;

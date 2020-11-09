library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  
  port (
    Master_IPMC_TCK   : in  std_logic;
    Master_IPMC_TMS   : in  std_logic;
    Master_IPMC_TDI   : in  std_logic;
    Master_IPMC_TDO   : out std_logic;
    Master_IPMC_nRST  : in  std_logic;
    Master_Cable_TCK  : in  std_logic;
    Master_Cable_TMS  : in  std_logic;
    Master_Cable_TDI  : in  std_logic;
    Master_Cable_TDO  : out std_logic;
    Master_Cable_nRST : in  std_logic;
    Master_Zynq_TCK   : in  std_logic_vector(1 downto 0);
    Master_Zynq_TMS   : in  std_logic_vector(1 downto 0);
    Master_Zynq_TDI   : in  std_logic_vector(1 downto 0);
    Master_Zynq_TDO   : out std_logic_vector(1 downto 0);
    Master_Zynq_nRST  : in  std_logic_vector(1 downto 0);
    Slave_Zynq_TCK    : out std_logic;
    Slave_Zynq_TMS    : out std_logic;
    Slave_Zynq_TDI    : out std_logic;
    Slave_Zynq_TDO    : in  std_logic;
    Slave_Zynq_nRST   : out std_logic;
    Slave_Mezz_TCK    : out std_logic_vector(1 downto 0);
    Slave_Mezz_TMS    : out std_logic_vector(1 downto 0);
    Slave_Mezz_TDI    : out std_logic_vector(1 downto 0);
    Slave_Mezz_TDO    : in  std_logic_vector(1 downto 0);
    Slave_Mezz_nRST   : out std_logic_vector(1 downto 0);
    sel               : in  std_logic_vector(2 downto 0);
    zynq_pwr_ngood    : in  std_logic;
    mezz_en           : in  std_logic_vector(1 downto 0);
    cable_present_n   : in  std_logic;
    GPIO              : in  std_logic_vector(3 downto 0);
    IPMC_UART         : in  std_logic_vector(3 downto 0);
    Zynq_GPIO         : in  std_logic_vector(3 downto 0);
    Mezz1_GPIO        : in  std_logic_vector(1 downto 0);
    Mezz2_GPIO        : in  std_logic_vector(1 downto 0)
    );

end entity top;

architecture behavioral of top is


  signal local_Board_TCK  : std_logic;
  signal local_Board_TMS  : std_logic;
  signal local_Board_TDI  : std_logic;
  signal local_Board_TDO  : std_logic;
  signal local_Board_nRST  : std_logic;

  begin  -- architecture behavioral

  IPMC_Cable_switch: process (cable_present_n,
                              Master_Cable_TCK, Master_Cable_TMS,Master_Cable_TDI,
                              Master_IPMC_TCK, Master_IPMC_TMS,Master_IPMC_TDI
                              ) is
  begin  -- process IPMC_Cable_switch
    if cable_present_n = '0' then
      --cable plugged in
      local_Board_TCK        <= Master_Cable_TCK;
      local_Board_TMS        <= Master_Cable_TMS;
      local_Board_TDI        <= Master_Cable_TDI;
      local_Board_nRST        <= Master_Cable_nRST;
      Master_Cable_TDO <= local_Board_TDO;
      --set IPMC TDO to zero
      Master_IPMC_TDO  <= 'Z';
    else
      --cable not plugged in (Use IPMC)
      local_Board_TCK        <= Master_IPMC_TCK;
      local_Board_TMS        <= Master_IPMC_TMS;
      local_Board_TDI        <= Master_IPMC_TDI;
      local_Board_nRST        <= Master_IPMC_nRST;
      Master_IPMC_TDO  <= local_Board_TDO;
      --set IPMC TDO to zero
      Master_Cable_TDO <= 'Z';      
    end if;
  end process IPMC_Cable_switch;

  switch: process (sel,mezz_en,zynq_pwr_ngood,
                   Master_Zynq_TCK,Master_Zynq_TMS,Master_Zynq_TDI,Master_Zynq_nRST,
                   local_Board_TCK,local_Board_TMS,local_Board_TDI,local_Board_nRST)  is
    variable mezzSel : integer range 0 to 1;
  begin  -- process switch
    mezzSel := to_integer(unsigned(sel(0 downto 0)));
    --default to high impedance
    Master_IPMC_TDO  <= 'Z';
    Master_Cable_TDO  <= 'Z';    
    Slave_Zynq_TCK   <= 'Z';
    Slave_Zynq_TMS   <= 'Z';
    Slave_Zynq_TDI   <= 'Z';
    Slave_Mezz_TCK   <= "ZZ";
    Slave_Mezz_TMS   <= "ZZ";
    Slave_Mezz_TDI   <= "ZZ";
    
    case sel(1 downto 0) is
      when "00" | "01" =>
        --Normal operation

        for iM in 0 to 1 loop
          --Connect Zynq masters to Mezz slaves
          if mezz_en(iM) = '1' and zynq_pwr_ngood = '0' then
            Slave_Mezz_TCK(iM)  <= Master_Zynq_TCK(iM);
            Slave_Mezz_TMS(iM)  <= Master_Zynq_TMS(iM);
            Slave_Mezz_TDI(iM)  <= Master_Zynq_TDI(iM);
            Slave_Mezz_nRST(iM)  <= Master_Zynq_nRST(iM);
            Master_Zynq_TDO(iM) <= Slave_Mezz_TDO(iM);
          else
            Slave_Mezz_TCK(iM)  <= 'Z';
            Slave_Mezz_TMS(iM)  <= 'Z';
            Slave_Mezz_TDI(iM)  <= 'Z';
            Slave_Mezz_nRST(iM)  <= 'Z';
            Master_Zynq_TDO(iM) <= 'Z';              
          end if;
        end loop;  -- iM

        --connect zynq slave to the board master
        if zynq_pwr_ngood = '0' then
          Slave_Zynq_TCK  <= local_Board_TCK;
          Slave_Zynq_TMS  <= local_Board_TMS;
          Slave_Zynq_TDI  <= local_Board_TDI;
          Slave_Zynq_nRST  <= local_Board_nRST;
          local_Board_TDO <= Slave_Zynq_TDO;
        else
          Slave_Zynq_TCK  <= 'Z';
          Slave_Zynq_TMS  <= 'Z';
          Slave_Zynq_TDI  <= 'Z';
          Slave_Zynq_nRST  <= 'Z';
          local_Board_TDO <= '0';
        end if;

      when "10" | "11" =>
        --Connect board master to selected mezz
        if mezz_en(mezzSel) = '1' and zynq_pwr_ngood = '0' then
          Slave_Mezz_TCK(mezzSel)  <= local_Board_TCK;
          Slave_Mezz_TMS(mezzSel)  <= local_Board_TMS;
          Slave_Mezz_TDI(mezzSel)  <= local_Board_TDI;
          Slave_Mezz_nRST(mezzSel)  <= local_Board_nRST;
          local_Board_TDO          <= Slave_Mezz_TDO(mezzSel);
        else
          Slave_Mezz_TCK(mezzSel)  <= 'Z';
          Slave_Mezz_TMS(mezzSel)  <= 'Z';
          Slave_Mezz_TDI(mezzSel)  <= 'Z';
          Slave_Mezz_nRST(mezzSel)  <= 'Z';
          local_Board_TDO          <= '0';              
        end if;
        
        --Connect other mezz to the correct zynq master
        if mezz_en(1 - mezzSel) = '1' and zynq_pwr_ngood = '0' then
          Slave_Mezz_TCK(1-mezzSel)  <= Master_Zynq_TCK(1-mezzSel);
          Slave_Mezz_TMS(1-mezzSel)  <= Master_Zynq_TMS(1-mezzSel);
          Slave_Mezz_TDI(1-mezzSel)  <= Master_Zynq_TDI(1-mezzSel);
          Slave_Mezz_nRST(1-mezzSel)  <= Master_Zynq_nRST(1-mezzSel);
          Master_Zynq_TDO(1-mezzSel) <= Slave_Mezz_TDO(1-mezzSel);
        else
          Slave_Mezz_TCK(1-mezzSel)  <= 'Z';
          Slave_Mezz_TMS(1-mezzSel)  <= 'Z';
          Slave_Mezz_TDI(1-mezzSel)  <= 'Z';
          Slave_Mezz_nRST(1-mezzSel)  <= 'Z';
          Master_Zynq_TDO(1-mezzSel) <= '0';              
        end if;
        
        
      when others => null;
    end case;
  end process switch;

  

end architecture behavioral;

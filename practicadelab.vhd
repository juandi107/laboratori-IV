
-- Entradas : CLOCK_50, KEY(0) = reset  
--            KEY = iniciar, SW(2 downto 0) = letra 
-- Salida   : LEDR(0) 
-- Punto = 0.5 s encendido, raya = 1.5 s encendido, separacion = 0.5 s apagado
--

--   estado    codigo   salidas 
--   reposo     000     carga
--   leer       001     limpiar
--   punto      010     led
--   raya1      011     led
--   raya2      100     led
--   raya3      101     led
--   espera     110     ninguna
--   avanzar    111     desplazar, restar

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity practicadelab is
    generic (
        HALF_CYCLES : positive := 25_000_000   -- 0.5 s con reloj de 50 MHz
    );
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(1 downto 0);
        SW       : in  std_logic_vector(2 downto 0);
        LEDR     : out std_logic_vector(0 downto 0)
    );
end entity practicadelab;

architecture rtl of practicadelab is

    type state_t is (reposo, leer, punto, raya1, raya2, raya3, espera, avanzar);
    -- Codificacion de los estados 
    attribute enum_encoding : string;
    attribute enum_encoding of state_t : type is
        "000 001 010 011 100 101 110 111";

    signal state, next_state : state_t;

    signal resetn  : std_logic;
    signal start_n : std_logic;

    -- Logica de seleccion de letra 
    signal pattern : std_logic_vector(3 downto 0);  -- 0 = punto, 1 = raya 
    signal length  : unsigned(2 downto 0);

    -- Registro de desplazamiento y contador 
    signal sreg      : std_logic_vector(3 downto 0);
    signal cont_long : unsigned(2 downto 0);

    -- Contador de medio segundo
    signal half_cnt : integer range 0 to HALF_CYCLES - 1;
    signal pulso    : std_logic;

    -- Salidas de la FSM 
    signal carga, desplazar, restar, limpiar : std_logic;
    signal led_next, led_reg : std_logic;

begin

    resetn  <= KEY(0);
    start_n <= KEY(1);

    
    -- Seleccion de letra

    process (SW)
    begin
        case SW is
            when "000" => pattern <= "0100"; length <= to_unsigned(2, 3); -- A  .-
            when "001" => pattern <= "1000"; length <= to_unsigned(4, 3); -- B  -...
            when "010" => pattern <= "1010"; length <= to_unsigned(4, 3); -- C  -.-.
            when "011" => pattern <= "1000"; length <= to_unsigned(3, 3); -- D  -..
            when "100" => pattern <= "0000"; length <= to_unsigned(1, 3); -- E  .
            when "101" => pattern <= "0010"; length <= to_unsigned(4, 3); -- F  ..-.
            when "110" => pattern <= "1100"; length <= to_unsigned(3, 3); -- G  --.
            when others => pattern <= "0000"; length <= to_unsigned(4, 3); -- H  ....
        end case;
    end process;

  
    -- Registro de desplazamiento , contador 
    process (CLOCK_50, resetn)
    begin
        if resetn = '0' then
            sreg      <= (others => '0');
            cont_long <= (others => '0');
        elsif rising_edge(CLOCK_50) then
            if carga = '1' then
                sreg      <= pattern;
                cont_long <= length;
            else
                if desplazar = '1' then
                    sreg <= sreg(2 downto 0) & '0';
                end if;
                if restar = '1' and cont_long /= 0 then
                    cont_long <= cont_long - 1;
                end if;
            end if;
        end if;
    end process;


    -- Contador de medio segundo

    process (CLOCK_50, resetn)
    begin
        if resetn = '0' then
            half_cnt <= 0;
        elsif rising_edge(CLOCK_50) then
            if limpiar = '1' or half_cnt = HALF_CYCLES - 1 then
                half_cnt <= 0;
            else
                half_cnt <= half_cnt + 1;
            end if;
        end if;
    end process;

    pulso <= '1' when half_cnt = HALF_CYCLES - 1 else '0';


    --  registro de estado 

    process (CLOCK_50, resetn)
    begin
        if resetn = '0' then
            state <= reposo;
        elsif rising_edge(CLOCK_50) then
            state <= next_state;
        end if;
    end process;


    -- logica de siguiente estado 
    process (state, start_n, pulso, sreg, cont_long)
    begin
        next_state <= state;

        case state is
            when reposo =>
                if start_n = '0' then
                    next_state <= leer;
                end if;

            when leer =>
                if cont_long = 0 then
                    next_state <= reposo;
                elsif sreg(3) = '1' then
                    next_state <= raya1;
                else
                    next_state <= punto;
                end if;

            when punto =>
                if pulso = '1' then
                    next_state <= espera;
                end if;

            when raya1 =>
                if pulso = '1' then
                    next_state <= raya2;
                end if;

            when raya2 =>
                if pulso = '1' then
                    next_state <= raya3;
                end if;

            when raya3 =>
                if pulso = '1' then
                    next_state <= espera;
                end if;

            when espera =>
                if pulso = '1' then
                    next_state <= avanzar;
                end if;

            when avanzar =>
                next_state <= leer;
        end case;
    end process;

    --  salidas 

    carga      <= '1' when state = reposo  else '0';
    limpiar    <= '1' when state = leer    else '0';
    desplazar  <= '1' when state = avanzar else '0';
    restar     <= '1' when state = avanzar else '0';
    led_next   <= '1' when (state = punto or state = raya1 or
                            state = raya2 or state = raya3) else '0';

 
    -- Salida reg
  
    process (CLOCK_50, resetn)
    begin
        if resetn = '0' then
            led_reg <= '0';
        elsif rising_edge(CLOCK_50) then
            led_reg <= led_next;
        end if;
    end process;

    LEDR(0) <= led_reg;

end architecture rtl;
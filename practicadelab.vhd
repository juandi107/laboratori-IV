
-- Entradas : CLOCK_50, KEY(0) = reset 
--            KEY(1) = iniciar, SW(2 downto 0) = letra 
-- Salida   : LEDR(0) = LED 
-- Punto = 0.5 s encendido, raya = 1.5 s encendido, separacion = 0.5 s apagado
--

--   estado    codigo   salidas 
--   reposo     000     carga
--   leer       001     limpiar
--   punto      010     led
--   raya1      011     led
--   raya2      100     led
--   raya3      101     led
--   espera     110     (ninguna)
--   avanzar    111     desplazar, restar

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity practicadelab is
    generic (
        CICLOS_MEDIO : positive := 25_000_000   -- 0.5 s con reloj de 50 MHz
    );
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(1 downto 0);
        SW       : in  std_logic_vector(2 downto 0);
        LEDR     : out std_logic_vector(0 downto 0)
    );
end entity practicadelab;

architecture comportamiento of practicadelab is

    type tipo_estado is (reposo, leer, punto, raya1, raya2, raya3, espera, avanzar);
    -- Codificacion de los estados 
    attribute enum_encoding : string;
    attribute enum_encoding of tipo_estado : type is
        "000 001 010 011 100 101 110 111";

    signal estado, sig_estado : tipo_estado;

    signal reinicio_n : std_logic;
    signal inicio_n   : std_logic;

    -- Logica de seleccion de letra 
    signal patron : std_logic_vector(3 downto 0);  -- 0 = punto, 1 = raya (MSB primero)
    signal longitud : unsigned(2 downto 0);

    -- Registro de desplazamiento y contador de longitud
    signal reg_morse : std_logic_vector(3 downto 0);
    signal cont_long : unsigned(2 downto 0);

    -- Contador de medio segundo
    signal cont_medio : integer range 0 to CICLOS_MEDIO - 1;
    signal pulso      : std_logic;

    -- Salidas de la FSM 
    signal carga, desplazar, restar, limpiar : std_logic;
    signal led_sig, led_reg : std_logic;

begin

    reinicio_n <= KEY(0);
    inicio_n   <= KEY(1);


    -- Seleccion de letra
 
    process (SW)
    begin
        case SW is
            when "000" => patron <= "0100"; longitud <= to_unsigned(2, 3); -- A  .-
            when "001" => patron <= "1000"; longitud <= to_unsigned(4, 3); -- B  -...
            when "010" => patron <= "1010"; longitud <= to_unsigned(4, 3); -- C  -.-.
            when "011" => patron <= "1000"; longitud <= to_unsigned(3, 3); -- D  -..
            when "100" => patron <= "0000"; longitud <= to_unsigned(1, 3); -- E  .
            when "101" => patron <= "0010"; longitud <= to_unsigned(4, 3); -- F  ..-.
            when "110" => patron <= "1100"; longitud <= to_unsigned(3, 3); -- G  --.
            when others => patron <= "0000"; longitud <= to_unsigned(4, 3); -- H  ....
        end case;
    end process;


    -- Registro de desplazamiento + contador 
  
    process (CLOCK_50, reinicio_n)
    begin
        if reinicio_n = '0' then
            reg_morse <= (others => '0');
            cont_long <= (others => '0');
        elsif rising_edge(CLOCK_50) then
            if carga = '1' then
                reg_morse <= patron;
                cont_long <= longitud;
            else
                if desplazar = '1' then
                    reg_morse <= reg_morse(2 downto 0) & '0';
                end if;
                if restar = '1' and cont_long /= 0 then
                    cont_long <= cont_long - 1;
                end if;
            end if;
        end if;
    end process;


    -- Contador de medio segundo
   
    process (CLOCK_50, reinicio_n)
    begin
        if reinicio_n = '0' then
            cont_medio <= 0;
        elsif rising_edge(CLOCK_50) then
            if limpiar = '1' or cont_medio = CICLOS_MEDIO - 1 then
                cont_medio <= 0;
            else
                cont_medio <= cont_medio + 1;
            end if;
        end if;
    end process;

    pulso <= '1' when cont_medio = CICLOS_MEDIO - 1 else '0';


    -- FSM: registro de estado 

    process (CLOCK_50, reinicio_n)
    begin
        if reinicio_n = '0' then
            estado <= reposo;
        elsif rising_edge(CLOCK_50) then
            estado <= sig_estado;
        end if;
    end process;

  
    -- FSM: logica de siguiente estado 
    
    process (estado, inicio_n, pulso, reg_morse, cont_long)
    begin
        sig_estado <= estado;

        case estado is
            when reposo =>
                if inicio_n = '0' then
                    sig_estado <= leer;
                end if;

            when leer =>
                if cont_long = 0 then
                    sig_estado <= reposo;
                elsif reg_morse(3) = '1' then
                    sig_estado <= raya1;
                else
                    sig_estado <= punto;
                end if;

            when punto =>
                if pulso = '1' then
                    sig_estado <= espera;
                end if;

            when raya1 =>
                if pulso = '1' then
                    sig_estado <= raya2;
                end if;

            when raya2 =>
                if pulso = '1' then
                    sig_estado <= raya3;
                end if;

            when raya3 =>
                if pulso = '1' then
                    sig_estado <= espera;
                end if;

            when espera =>
                if pulso = '1' then
                    sig_estado <= avanzar;
                end if;

            when avanzar =>
                sig_estado <= leer;
        end case;
    end process;

    -- FSM: salidas
 
    carga     <= '1' when estado = reposo  else '0';
    limpiar   <= '1' when estado = leer    else '0';
    desplazar <= '1' when estado = avanzar else '0';
    restar    <= '1' when estado = avanzar else '0';
    led_sig   <= '1' when (estado = punto or estado = raya1 or
                           estado = raya2 or estado = raya3) else '0';

    -- Salida registrada 

    process (CLOCK_50, reinicio_n)
    begin
        if reinicio_n = '0' then
            led_reg <= '0';
        elsif rising_edge(CLOCK_50) then
            led_reg <= led_sig;
        end if;
    end process;

    LEDR(0) <= led_reg;

end architecture comportamiento;
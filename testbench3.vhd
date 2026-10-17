library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_testbench3 is
end entity tb_testbench3;

architecture simulacion of tb_testbench3 is

    constant CICLOS_MEDIO  : positive := 40;
    constant PERIODO_RELOJ : time := 20 ns;

    signal CLOCK_50 : std_logic := '0';
    signal KEY      : std_logic_vector(1 downto 0) := "11";
    signal SW       : std_logic_vector(2 downto 0) := "000";
    signal LEDR     : std_logic_vector(0 downto 0);

    -- esperado por cada medio segundo 
    -- punto = "10", raya = "1110"  
    function esperado(i : integer) return string is
    begin
        case i is
            when 0 => return "10" & "1110";                    -- A  .-
            when 1 => return "1110" & "10" & "10" & "10";      -- B  -...
            when 2 => return "1110" & "10" & "1110" & "10";    -- C  -.-.
            when 3 => return "1110" & "10" & "10";             -- D  -..
            when 4 => return "10";                             -- E  .
            when 5 => return "10" & "10" & "1110" & "10";      -- F  ..-.
            when 6 => return "1110" & "1110" & "10";           -- G  --.
            when others => return "10" & "10" & "10" & "10";   -- H  ....
        end case;
    end function;

begin

    CLOCK_50 <= not CLOCK_50 after PERIODO_RELOJ / 2;

    circuito : entity work.practicadelab
        generic map (CICLOS_MEDIO => CICLOS_MEDIO)
        port map (CLOCK_50 => CLOCK_50, KEY => KEY, SW => SW, LEDR => LEDR);

    estimulo : process
        variable patron_esp : string(1 to 16);
        variable largo      : integer;
        variable errores    : integer := 0;
    begin
        -- Reset inicial
        KEY <= "10";
        wait for 3 * PERIODO_RELOJ;
        KEY <= "11";
        wait for 3 * PERIODO_RELOJ;
        assert LEDR(0) = '0' report "LED debe estar apagado en reposo" severity error;

        for i in 0 to 7 loop
            SW <= std_logic_vector(to_unsigned(i, 3));
            wait until rising_edge(CLOCK_50);
            KEY(1) <= '0';                       -- presionar KEY1
            wait for 3 * PERIODO_RELOJ;
            KEY(1) <= '1';                       -- soltar KEY1

           
            wait until LEDR(0) = '1' for 50 * PERIODO_RELOJ;
            assert LEDR(0) = '1' report "El LED nunca se encendio" severity failure;
            wait for (CICLOS_MEDIO / 2) * PERIODO_RELOJ;

            largo := esperado(i)'length;
            patron_esp(1 to largo) := esperado(i);
            for k in 1 to largo loop
                if patron_esp(k) = '1' then
                    assert LEDR(0) = '1'
                        report "Letra " & integer'image(i) & ": se esperaba LED=1 en el intervalo " & integer'image(k)
                        severity error;
                else
                    assert LEDR(0) = '0'
                        report "Letra " & integer'image(i) & ": se esperaba LED=0 en el intervalo " & integer'image(k)
                        severity error;
                end if;
                wait for CICLOS_MEDIO * PERIODO_RELOJ;
            end loop;

            
            wait for 4 * CICLOS_MEDIO * PERIODO_RELOJ;
            assert LEDR(0) = '0' report "LED debe quedar apagado al terminar" severity error;
            report "Letra " & integer'image(i) & " verificada";
        end loop;

        -- Prueba de reset 
        SW <= "111";
        wait until rising_edge(CLOCK_50);
        KEY(1) <= '0';
        wait for 3 * PERIODO_RELOJ;
        KEY(1) <= '1';
        wait until LEDR(0) = '1' for 50 * PERIODO_RELOJ;
        wait for 2 * PERIODO_RELOJ;
        wait for 3 ns;                           -- fuera del flanco 
        KEY(0) <= '0';
        wait for 1 ns;
        assert LEDR(0) = '0' report "El reset asincrono no apago el LED" severity error;
        wait for 2 * PERIODO_RELOJ;
        KEY(0) <= '1';
        wait for 6 * CICLOS_MEDIO * PERIODO_RELOJ;
        assert LEDR(0) = '0' report "Tras reset la FSM debe permanecer en reposo" severity error;

        report "Simulacion terminada";
        wait;
    end process;

end architecture simulacion ;

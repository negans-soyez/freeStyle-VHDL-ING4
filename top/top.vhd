library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        reset  : in  STD_LOGIC;
        clk50  : in  STD_LOGIC;
        hsync  : out STD_LOGIC;
        vsync  : out STD_LOGIC;
        blank  : inout STD_LOGIC;
        red    : out STD_LOGIC_VECTOR(3 downto 0);
        green  : out STD_LOGIC_VECTOR(3 downto 0);
        blue   : out STD_LOGIC_VECTOR(3 downto 0)
    );
end top;

architecture Behavioral of top is

    --------------------------------------------------------------------
    -- Composants VGA et ADC
    --------------------------------------------------------------------
    component controlVGA
        port(
            clk, reset : in std_logic;
            rIn, gIn, bIn : in STD_LOGIC_VECTOR(3 downto 0);
            rOut, gOut, bOut : out STD_LOGIC_VECTOR(3 downto 0);
            beamX, beamY : out std_logic_vector(9 downto 0);
            beamValid : out std_logic;
            blank : inout std_logic;
            vsync, hsync : out std_logic
        );
    end component;

    component adc_controller
        port (
            CLOCK, RESET : in std_logic;
            CH0, CH1, CH2, CH3, CH4, CH5, CH6, CH7 : out std_logic_vector(11 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Signaux VGA et ADC
    --------------------------------------------------------------------
    signal beamX, beamY : std_logic_vector(9 downto 0);
    signal beamValid : std_logic;
    signal rSig_int, gSig_int, bSig_int : std_logic_vector(3 downto 0);
    signal CH0 : std_logic_vector(11 downto 0);
    signal raw_vx : unsigned(11 downto 0);

    --------------------------------------------------------------------
    -- Constantes d’affichage
    --------------------------------------------------------------------
    constant SCREEN_WIDTH  : integer := 640;
    constant SCREEN_HEIGHT : integer := 480;
    constant FRAME_SIZE    : integer := 400;

    constant FRAME_X_START : integer := (SCREEN_WIDTH  - FRAME_SIZE)/2;
    constant FRAME_Y_START : integer := (SCREEN_HEIGHT - FRAME_SIZE)/2;
    constant FRAME_X_END   : integer := FRAME_X_START + FRAME_SIZE;
    constant FRAME_Y_END   : integer := FRAME_Y_START + FRAME_SIZE;

    constant PADDLE_WIDTH  : integer := 80;
    constant PADDLE_HEIGHT : integer := 10;
    constant PADDLE_Y      : integer := FRAME_Y_END - 30;
    constant PADDLE_X_INIT : integer := (SCREEN_WIDTH/2) - (PADDLE_WIDTH/2);

    constant BRICK_WIDTH   : integer := 30;
    constant BRICK_HEIGHT  : integer := 10;

    constant BALL_RADIUS   : integer := 6;
    constant BALL_XC_INIT  : integer := (SCREEN_WIDTH/2) - (PADDLE_WIDTH/2);
    constant BALL_YC_INIT  : integer := FRAME_Y_END - 70;
	 
	 

    --------------------------------------------------------------------
    -- Signaux balle, direction et paddle
    --------------------------------------------------------------------
    signal posX, next_posX : unsigned(9 downto 0) := to_unsigned(BALL_XC_INIT, 10);
    signal posY, next_posY : unsigned(9 downto 0) := to_unsigned(BALL_YC_INIT, 10);
    signal dirX, next_dirX : integer range -2 to 2 := 0;
    signal dirY, next_dirY : integer range -2 to 2 := -1;
    signal paddle_hit : std_logic;
    signal impact_offset : integer;
    signal paddle_x, next_paddle_x : integer := PADDLE_X_INIT;
	 
	 signal player_dead, next_player_dead : std_logic := '0';


    signal x, y : integer;

    --------------------------------------------------------------------
    -- Compteurs imbriqués
    --------------------------------------------------------------------
    signal add, cpt, mux, mux2 : std_logic_vector(23 downto 0);
    signal comp, comp2 : std_logic;
    signal add2, cpt2, mux3 : std_logic_vector(23 downto 0);

    --------------------------------------------------------------------
    -- Brique
    --------------------------------------------------------------------
    signal brick_alive : std_logic := '1';
    signal next_brick_alive : std_logic;
    signal brick_hit : std_logic := '0';
    signal hit_side : std_logic_vector(1 downto 0);
	 

begin

    --------------------------------------------------------------------
    -- Instanciation des modules VGA et ADC
    --------------------------------------------------------------------
    u_adc : adc_controller
        port map (
            CLOCK => clk50,
            RESET => reset,
            CH0 => CH0,
            CH1 => open, CH2 => open, CH3 => open,
            CH4 => open, CH5 => open, CH6 => open, CH7 => open
        );

    iVGA : controlVGA
        port map (
            clk => clk50,
            reset => reset,
            rIn => rSig_int, gIn => gSig_int, bIn => bSig_int,
            rOut => open, gOut => open, bOut => open,
            beamValid => beamValid, beamX => beamX, beamY => beamY,
            blank => blank, hsync => hsync, vsync => vsync
        );

    --------------------------------------------------------------------
    -- Coordonnées VGA et joystick
    --------------------------------------------------------------------
    x <= to_integer(unsigned(beamX));
    y <= to_integer(unsigned(beamY));
    raw_vx <= unsigned(CH0);

    --------------------------------------------------------------------
    -- Compteurs imbriqués
    --------------------------------------------------------------------
    add  <= std_logic_vector(unsigned(cpt) + 1);
    add2 <= std_logic_vector(unsigned(cpt2) + 1);
    mux  <= add when comp2 = '1' else cpt;
    comp  <= '1' when unsigned(mux) = 4 else '0';
    comp2 <= '1' when unsigned(add2) = to_unsigned(150000, add2'length) else '0';
    mux2 <= (others => '0') when comp = '1' else mux;
    mux3 <= (others => '0') when comp2 = '1' else add2;
    cpt  <= (others => '0') when reset = '1' else mux2 when rising_edge(clk50);
    cpt2 <= (others => '0') when reset = '1' else mux3 when rising_edge(clk50);

    --------------------------------------------------------------------
    -- Déplacement du paddle
    --------------------------------------------------------------------
    next_paddle_x <=
        PADDLE_X_INIT when reset = '1' else
        paddle_x - 4 when (to_integer(raw_vx) < 480 and comp2='1' and paddle_x > FRAME_X_START) else
        paddle_x - 2 when (to_integer(raw_vx) < 620 and comp2='1' and paddle_x > FRAME_X_START) else
        paddle_x + 2 when (to_integer(raw_vx) > 680 and comp2='1' and paddle_x < FRAME_X_END - PADDLE_WIDTH) else
        paddle_x + 4 when (to_integer(raw_vx) > 820 and comp2='1' and paddle_x < FRAME_X_END - PADDLE_WIDTH) else
        paddle_x;
    paddle_x <= next_paddle_x when rising_edge(clk50);

    --------------------------------------------------------------------
    -- Collision raquette
    --------------------------------------------------------------------
    paddle_hit <= '1' when (
        dirY > 0 and
        to_integer(posY) + BALL_RADIUS >= PADDLE_Y and
        to_integer(posY) + BALL_RADIUS <= PADDLE_Y + PADDLE_HEIGHT and
        to_integer(posX) >= paddle_x and
        to_integer(posX) <= paddle_x + PADDLE_WIDTH
    ) else '0';
    impact_offset <= to_integer(posX) - (paddle_x + PADDLE_WIDTH / 2);

    --------------------------------------------------------------------
    -- Collision brique
    --------------------------------------------------------------------
    brick_hit <= '1' when (
        brick_alive = '1' and
        to_integer(posX) + BALL_RADIUS >= 320 - BRICK_WIDTH and
        to_integer(posX) - BALL_RADIUS <= 320 and
        to_integer(posY) + BALL_RADIUS >= 260 and
        to_integer(posY) - BALL_RADIUS <= 260 + BRICK_HEIGHT
    ) else '0';

    hit_side <= "10" when (
        abs((to_integer(posY) + BALL_RADIUS) - 260) < 4 or
        abs((to_integer(posY) - BALL_RADIUS) - (260 + BRICK_HEIGHT)) < 4
    ) else "01" when (
        abs((to_integer(posX) + BALL_RADIUS) - (320 - BRICK_WIDTH)) < 4 or
        abs((to_integer(posX) - BALL_RADIUS) - 320) < 4
    ) else "00";

    next_brick_alive <= '1' when reset = '1' else
                        '0' when brick_hit = '1' else
                        brick_alive;
								
	 --------------------------------------------------------------------
    -- Gestion de la mort du joueur
    --------------------------------------------------------------------
	next_player_dead <= 
		 '0' when reset = '1' elsE
		 '1' when (to_integer(posY) > FRAME_Y_END) else
		 player_dead;



	--------------------------------------------------------------------
	-- Direction et position de la balle (sans demi-vitesse)
	--------------------------------------------------------------------
	-- Calcul de la direction horizontale
	next_dirX <= 
		 0 when reset = '1' else
		 -- rebond sur les bords gauche/droite ou sur brique
		 -dirX when (
			  (to_integer(posX) >= FRAME_X_END - BALL_RADIUS and dirX > 0) or
			  (to_integer(posX) <= FRAME_X_START + BALL_RADIUS and dirX < 0) or
			  (brick_hit = '1' and hit_side = "01")
		 ) else
		 -- rebond sur la raquette selon la zone d’impact
		 -2 when (paddle_hit = '1' and impact_offset < -20) else   -- fort angle gauche
		 -1 when (paddle_hit = '1' and impact_offset < -10) else   -- moyen gauche
		  1 when (paddle_hit = '1' and impact_offset > 10) else    -- moyen droite
		  2 when (paddle_hit = '1' and impact_offset > 20) else    -- fort angle droite
		  dirX;

	-- Calcul de la direction verticale
	next_dirY <= 
		 -1 when reset = '1' else
		 -- rebond sur le haut, raquette ou brique
		 -dirY when (
			  (to_integer(posY) <= FRAME_Y_START + BALL_RADIUS and dirY < 0) or
			  (paddle_hit = '1') or
			  (brick_hit = '1' and hit_side = "10")
		 ) else
		 dirY;

    -- Position horizontale
    next_posX <= to_unsigned(BALL_XC_INIT, 10) when reset = '1' else
                 posX when player_dead = '1' else
                 to_unsigned(to_integer(posX) + dirX, 10) when (comp = '1') else
                 posX;

    -- Position verticale
    next_posY <= to_unsigned(BALL_YC_INIT, 10) when reset = '1' else
                 posY when player_dead = '1' else
                 to_unsigned(to_integer(posY) + dirY, 10) when (comp = '1') else
                 posY;





    --------------------------------------------------------------------
    -- Registres synchrones
    --------------------------------------------------------------------
    posX <= next_posX when rising_edge(clk50);
    posY <= next_posY when rising_edge(clk50);
    dirX <= next_dirX when rising_edge(clk50);
    dirY <= next_dirY when rising_edge(clk50);
    brick_alive <= next_brick_alive when rising_edge(clk50);
	 player_dead <= next_player_dead when rising_edge(clk50);


    --------------------------------------------------------------------
    -- Dessin cadre, paddle, brique et balle
    --------------------------------------------------------------------
    rSig_int <=
        "1111" when (
            beamValid='1' and (
                (y = FRAME_Y_START and x >= FRAME_X_START and x <= FRAME_X_END) or
                (y = FRAME_Y_END and x >= FRAME_X_START and x <= FRAME_X_END) or
                (x = FRAME_X_START and y >= FRAME_Y_START and y <= FRAME_Y_END) or
                (x = FRAME_X_END and y >= FRAME_Y_START and y <= FRAME_Y_END)
            )
        )
        else "1111" when (
            beamValid='1' and
            x >= paddle_x and x < paddle_x + PADDLE_WIDTH and
            y >= PADDLE_Y and y < PADDLE_Y + PADDLE_HEIGHT
        )
        else "1111" when (
            beamValid='1' and brick_alive = '1' and
            x >= 320 - BRICK_WIDTH and x < 320 and
            y >= 260 and y < 260 + BRICK_HEIGHT
        )
        else "1111" when (
            beamValid='1' and player_dead = '0' and
            ((x - to_integer(posX))*(x - to_integer(posX)) +
             (y - to_integer(posY))*(y - to_integer(posY))) <= BALL_RADIUS*BALL_RADIUS
        )
        else (others => '0');

    --------------------------------------------------------------------
    -- Couleurs
    --------------------------------------------------------------------
    gSig_int <=
        "0000" when (
            beamValid='1' and brick_alive = '1' and
            x >= 320 - BRICK_WIDTH and x < 320 and
            y >= 260 and y < 260 + BRICK_HEIGHT
        )
        else rSig_int;

    bSig_int <= rSig_int;

    red <= rSig_int;
    green <= gSig_int;
    blue <= bSig_int;

end Behavioral;

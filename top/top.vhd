library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        reset  : in  STD_LOGIC;
        clk50  : in  STD_LOGIC;
        hsync  : buffer STD_LOGIC;  -- pour pouvoir lire le signal si besoin
        vsync  : buffer STD_LOGIC;
        blank  : inout STD_LOGIC;
        red    : out STD_LOGIC_VECTOR(3 downto 0);
        green  : out STD_LOGIC_VECTOR(3 downto 0);
        blue   : out STD_LOGIC_VECTOR(3 downto 0)
    );
end top;

architecture Behavioral of top is

    --------------------------------------------------------------------
    -- Composant VGA
    --------------------------------------------------------------------
    COMPONENT controlVGA
        PORT(
            clk        : in  std_logic;
            reset      : in  std_logic;
            rIn, gIn, bIn : in  STD_LOGIC_VECTOR(3 downto 0);
            rOut, gOut, bOut : out STD_LOGIC_VECTOR(3 downto 0);
            beamX, beamY : out std_logic_vector(9 downto 0);
            beamValid : out std_logic;
            blank     : inout std_logic;
            vsync, hsync : out std_logic
        );
    END COMPONENT;

    --------------------------------------------------------------------
    -- Signaux internes VGA
    --------------------------------------------------------------------
    signal beamX, beamY : std_logic_vector(9 downto 0);
    signal beamValid    : std_logic;

    signal rSig_int, gSig_int, bSig_int : STD_LOGIC_VECTOR(3 downto 0);

    --------------------------------------------------------------------
    -- Constantes géométriques
    --------------------------------------------------------------------
    constant SCREEN_WIDTH  : integer := 640;
    constant SCREEN_HEIGHT : integer := 480;

    constant FRAME_SIZE    : integer := 400;
    constant FRAME_X_START : integer := (SCREEN_WIDTH  - FRAME_SIZE) / 2;
    constant FRAME_Y_START : integer := (SCREEN_HEIGHT - FRAME_SIZE) / 2;
    constant FRAME_X_END   : integer := FRAME_X_START + FRAME_SIZE;
    constant FRAME_Y_END   : integer := FRAME_Y_START + FRAME_SIZE;

    constant PADDLE_WIDTH  : integer := 80;
    constant PADDLE_HEIGHT : integer := 10;
    constant PADDLE_X      : integer := (SCREEN_WIDTH / 2) - (PADDLE_WIDTH / 2);
    constant PADDLE_Y      : integer := FRAME_Y_END - 30;

    constant BRICK_WIDTH  : integer := 30;
    constant BRICK_HEIGHT : integer := 10;

    constant BALL_RADIUS : integer := 6;
    constant BALL_XC_INIT : integer := (SCREEN_WIDTH / 2);
    constant BALL_YC_INIT : integer := 200;

    --------------------------------------------------------------------
    -- Signaux pour la balle
    --------------------------------------------------------------------
    signal counter, next_counter : unsigned(23 downto 0) := (others => '0');
    signal posX, next_posX       : unsigned(9 downto 0) := to_unsigned(BALL_XC_INIT, 10);
    signal posY, next_posY       : unsigned(9 downto 0) := to_unsigned(BALL_YC_INIT, 10);
    signal dirX, next_dirX       : std_logic := '1'; -- 1 = droite, 0 = gauche
    signal dirY, next_dirY       : std_logic := '1'; -- 1 = descend, 0 = monte
    signal comp                  : std_logic;
    signal paddle_hit            : std_logic;
    signal impact_offset         : integer;

    signal x, y : integer;

begin

    --------------------------------------------------------------------
    -- Conversion coordonnées VGA
    --------------------------------------------------------------------
    x <= to_integer(unsigned(beamX));
    y <= to_integer(unsigned(beamY));

    --------------------------------------------------------------------
    -- Compteur lent pour le mouvement
    --------------------------------------------------------------------
    next_counter <= (others => '0') when reset = '1' else counter + 1;
    counter <= next_counter when rising_edge(clk50);
    comp <= counter(18);  -- vitesse de la balle (ajuste le bit pour plus lent/rapide)

    --------------------------------------------------------------------
    -- Détection collision raquette
    --------------------------------------------------------------------
    paddle_hit <= '1' when (
        dirY = '1' and
        to_integer(posY) + BALL_RADIUS >= PADDLE_Y and
        to_integer(posY) + BALL_RADIUS <= PADDLE_Y + PADDLE_HEIGHT and
        to_integer(posX) >= PADDLE_X and
        to_integer(posX) <= PADDLE_X + PADDLE_WIDTH
    ) else '0';

    -- distance par rapport au centre de la raquette
    impact_offset <= to_integer(posX) - (PADDLE_X + PADDLE_WIDTH / 2);

    --------------------------------------------------------------------
    -- Direction horizontale suivante
    --------------------------------------------------------------------
    next_dirX <= '1' when reset = '1' else
                 '0' when (dirX = '1' and to_integer(posX) >= FRAME_X_END - BALL_RADIUS) else
                 '1' when (dirX = '0' and to_integer(posX) <= FRAME_X_START + BALL_RADIUS) else
                 '0' when (paddle_hit = '1' and impact_offset < -10) else
                 '1' when (paddle_hit = '1' and impact_offset > 10) else
                 dirX;

    --------------------------------------------------------------------
    -- Direction verticale suivante
    --------------------------------------------------------------------
    next_dirY <= '1' when reset = '1' else
                 '0' when (dirY = '1' and (
                     to_integer(posY) >= FRAME_Y_END - BALL_RADIUS or paddle_hit = '1'
                 )) else
                 '1' when (dirY = '0' and to_integer(posY) <= FRAME_Y_START + BALL_RADIUS) else
                 dirY;

    --------------------------------------------------------------------
    -- Position suivante horizontale
    --------------------------------------------------------------------
    next_posX <= to_unsigned(BALL_XC_INIT, 10) when reset = '1' else
                 posX + 1 when (comp = '1' and dirX = '1' and to_integer(posX) < FRAME_X_END - BALL_RADIUS) else
                 posX - 1 when (comp = '1' and dirX = '0' and to_integer(posX) > FRAME_X_START + BALL_RADIUS) else
                 posX;

    --------------------------------------------------------------------
    -- Position suivante verticale
    --------------------------------------------------------------------
    next_posY <= to_unsigned(BALL_YC_INIT, 10) when reset = '1' else
                 posY + 1 when (comp = '1' and dirY = '1' and to_integer(posY) < FRAME_Y_END - BALL_RADIUS and paddle_hit = '0') else
                 posY - 1 when (comp = '1' and dirY = '0' and to_integer(posY) > FRAME_Y_START + BALL_RADIUS) else
                 posY;

    --------------------------------------------------------------------
    -- Registres synchrones simulés (sans process)
    --------------------------------------------------------------------
    posX <= next_posX when rising_edge(clk50);
    posY <= next_posY when rising_edge(clk50);
    dirX <= next_dirX when rising_edge(clk50);
    dirY <= next_dirY when rising_edge(clk50);

    --------------------------------------------------------------------
    -- Génération combinatoire (dessin)
    --------------------------------------------------------------------
    rSig_int <=
        -- Cadre
        "1111" when (
            beamValid='1' and (
                (y = FRAME_Y_START and x >= FRAME_X_START and x <= FRAME_X_END) or
                (y = FRAME_Y_END   and x >= FRAME_X_START and x <= FRAME_X_END) or
                (x = FRAME_X_START and y >= FRAME_Y_START and y <= FRAME_Y_END) or
                (x = FRAME_X_END   and y >= FRAME_Y_START and y <= FRAME_Y_END)
            )
        )
        -- Paddle
        else "1111" when (
            beamValid='1' and
            x >= PADDLE_X and x < PADDLE_X + PADDLE_WIDTH and
            y >= PADDLE_Y and y < PADDLE_Y + PADDLE_HEIGHT
        )
        -- Brique rouge
        else "1111" when (
            beamValid='1' and
            x >= 320 and x < 320 + BRICK_WIDTH and
            y >= 260 and y < 260 + BRICK_HEIGHT
        )
        -- Balle mobile
        else "1111" when (
            beamValid='1' and
            ((x - to_integer(posX))*(x - to_integer(posX)) + 
             (y - to_integer(posY))*(y - to_integer(posY))) <= BALL_RADIUS*BALL_RADIUS
        )
        else (others => '0');

    --------------------------------------------------------------------
    -- Couleurs secondaires
    --------------------------------------------------------------------
    gSig_int <=
        "0000" when (
            beamValid='1' and
            x >= 320 - BRICK_WIDTH and x < 320 and
            y >= 260 and y < 260 + BRICK_HEIGHT
        )
        else rSig_int;

    bSig_int <= gSig_int;

    --------------------------------------------------------------------
    -- Sorties VGA
    --------------------------------------------------------------------
    red   <= rSig_int;
    green <= gSig_int;
    blue  <= bSig_int;

    --------------------------------------------------------------------
    -- Instanciation du contrôleur VGA
    --------------------------------------------------------------------
    iCtlVga: controlVGA
        PORT MAP (
            clk       => clk50,
            reset     => reset,
            rIn       => rSig_int,
            gIn       => gSig_int,
            bIn       => bSig_int,
            rOut      => open,
            gOut      => open,
            bOut      => open,
            beamValid => beamValid,
            beamX     => beamX,
            beamY     => beamY,
            blank     => blank,
            hsync     => hsync,
            vsync     => vsync
        );

end Behavioral;

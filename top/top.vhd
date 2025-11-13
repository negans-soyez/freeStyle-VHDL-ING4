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

    -- dirX étendu pour un gameplay équilibré
    signal dirX, next_dirX : integer range -4 to 4 := 0;
    signal dirY, next_dirY : integer range -2 to 2 := -1;
	 
	 signal sign_dirX : integer range -1 to 1;
	 signal sign_dirY : integer range -1 to 1;


    signal paddle_hit : std_logic;
    signal impact_offset : integer;
    signal impact_norm   : integer range -100 to 100;
    signal impact_dir    : integer range -4 to 4;
    signal spin          : integer range -1 to 1;
    signal raw_dirX      : integer range -8 to 8;
    signal final_dirX    : integer range -4 to 4;

    signal paddle_x, next_paddle_x : integer := PADDLE_X_INIT;
    signal joy_delta : integer range -600 to 600;
    signal joy_speed : integer range -10 to 10;

    signal player_dead, next_player_dead : std_logic := '0';

    signal x, y : integer;

    --------------------------------------------------------------------
    -- Compteurs imbriqués
    --------------------------------------------------------------------
    signal add, cpt, mux, mux2 : std_logic_vector(23 downto 0);
    signal comp, comp2 : std_logic;
    signal add2, cpt2, mux3 : std_logic_vector(23 downto 0);

	--------------------------------------------------------------------
	-- BRIQUES : triangle pointe vers le paddle (4-3-2-1 briques)
	--------------------------------------------------------------------
	constant NBRICKS : integer := 10;

	type brick_array is array (0 to NBRICKS-1) of integer;

	constant TRI_START_Y : integer := FRAME_Y_START + 40;
	constant SPACING_X   : integer := 40;
	constant SPACING_Y   : integer := 25;
	constant CX          : integer := 320;

	-- Triangle 4,3,2,1 briques
	constant BRICK_X : brick_array := (
		 0 => CX - 60,
		 1 => CX - 20,
		 2 => CX + 20,
		 3 => CX + 60,

		 4 => CX - 40,
		 5 => CX,
		 6 => CX + 40,

		 7 => CX - 20,
		 8 => CX + 20,

		 9 => CX
	);

	constant BRICK_Y : brick_array := (
		 0 => TRI_START_Y,
		 1 => TRI_START_Y,
		 2 => TRI_START_Y,
		 3 => TRI_START_Y,

		 4 => TRI_START_Y + SPACING_Y,
		 5 => TRI_START_Y + SPACING_Y,
		 6 => TRI_START_Y + SPACING_Y,

		 7 => TRI_START_Y + 2*SPACING_Y,
		 8 => TRI_START_Y + 2*SPACING_Y,

		 9 => TRI_START_Y + 3*SPACING_Y
	);

	signal brick_alive_vec      : std_logic_vector(NBRICKS-1 downto 0) := (others => '1');
	signal next_brick_alive_vec : std_logic_vector(NBRICKS-1 downto 0);

	signal brick_hit_vec  : std_logic_vector(NBRICKS-1 downto 0);
	signal brick_side_vec : std_logic_vector(2*NBRICKS-1 downto 0);
	signal brick_hit : std_logic;


	signal hit_index : integer range 0 to NBRICKS-1;
	signal brick_pixel_vec : std_logic_vector(NBRICKS-1 downto 0);
	signal brick_pixel : std_logic;
	
	--------------------------------------------------------------------
	-- SCORE
	--------------------------------------------------------------------
	signal score      : integer range 0 to 999 := 0;
	signal next_score : integer range 0 to 999 := 0;

	-- digits du score
	signal score_d0 : std_logic_vector(3 downto 0);
	signal score_d1 : std_logic_vector(3 downto 0);
	signal score_d2 : std_logic_vector(3 downto 0);

	
	signal rDigit0, gDigit0, bDigit0 : std_logic_vector(3 downto 0);
	signal rDigit1, gDigit1, bDigit1 : std_logic_vector(3 downto 0);
	signal rDigit2, gDigit2, bDigit2 : std_logic_vector(3 downto 0);
	

	signal speed_bonus : integer range 0 to 3 := 0;
	signal next_speed_bonus : integer range 0 to 3 := 0;






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
    -- Déplacement du paddle (joystick proportionnel, sensibilité réduite)
    --------------------------------------------------------------------
    -- Écart par rapport au centre (≈600)
    joy_delta <= to_integer(raw_vx) - 600;

    -- Vitesse proportionnelle avec sensibilité réduite
    joy_speed <=
        0 when reset = '1' else
        0 when abs(joy_delta) < 20 else      -- petite dead-zone naturelle
        joy_delta / 130;                     -- sensibilité réduite

    next_paddle_x <=
        PADDLE_X_INIT when reset = '1' else
        -- Déplacement proportionnel
        paddle_x + joy_speed
            when (comp2 = '1'
              and paddle_x + joy_speed >= FRAME_X_START
              and paddle_x + joy_speed <= FRAME_X_END - PADDLE_WIDTH) else
        paddle_x;

    paddle_x <= next_paddle_x when rising_edge(clk50);

    --------------------------------------------------------------------
    -- Collision raquette + calcul du rebond (équilibré + spin)
    --------------------------------------------------------------------
    paddle_hit <= '1' when (
        dirY > 0 and
        to_integer(posY) + BALL_RADIUS >= PADDLE_Y and
        to_integer(posY) + BALL_RADIUS <= PADDLE_Y + PADDLE_HEIGHT and
        to_integer(posX) >= paddle_x and
        to_integer(posX) <= paddle_x + PADDLE_WIDTH
    ) else '0';

    -- Offset par rapport au centre de la raquette
    impact_offset <= to_integer(posX) - (paddle_x + PADDLE_WIDTH / 2);

    -- Normalisation grossière entre -100 et +100
    impact_norm <= (impact_offset * 100) / (PADDLE_WIDTH / 2);

    -- Direction de base en fonction de la zone d’impact (équilibré)
    impact_dir <=
          -4 when impact_norm < -75 else
          -3 when impact_norm < -50 else
          -2 when impact_norm < -25 else
          -1 when impact_norm < -10 else
           0 when impact_norm <= 10 else
           1 when impact_norm <= 25 else
           2 when impact_norm <= 50 else
           3 when impact_norm <= 75 else
           4;

    -- Effet "spin" : on regarde le mouvement du paddle au moment du contact
    -- joy_speed < 0 : paddle vers la gauche -> spin négatif
    -- joy_speed > 0 : paddle vers la droite -> spin positif
    spin <=
        -1 when (paddle_hit = '1' and joy_speed < 0) else
         1 when (paddle_hit = '1' and joy_speed > 0) else
         0;

    -- Direction brute = impact + spin
    raw_dirX <= impact_dir + spin;

    -- Saturation dans [-4 .. 4] pour rester dans la plage de dirX
    final_dirX <=
        -4 when raw_dirX < -4 else
         4 when raw_dirX > 4 else
         raw_dirX;

	--------------------------------------------------------------------
	-- Collision par brique (sans process)
	--------------------------------------------------------------------
	gen_coll : for i in 0 to NBRICKS-1 generate
	begin
		 brick_hit_vec(i) <=
			  '1' when (
					brick_alive_vec(i) = '1' and
					to_integer(posX) + BALL_RADIUS >= BRICK_X(i) and
					to_integer(posX) - BALL_RADIUS <= BRICK_X(i) + BRICK_WIDTH and
					to_integer(posY) + BALL_RADIUS >= BRICK_Y(i) and
					to_integer(posY) - BALL_RADIUS <= BRICK_Y(i) + BRICK_HEIGHT
			  )
			  else '0';

		 brick_side_vec(2*i+1 downto 2*i) <=
			  "10" when (
					abs((to_integer(posY)+BALL_RADIUS) - BRICK_Y(i)) < 4 or
					abs((to_integer(posY)-BALL_RADIUS) - (BRICK_Y(i)+BRICK_HEIGHT)) < 4
			  )
			  else "01" when (
					abs((to_integer(posX)+BALL_RADIUS) - BRICK_X(i)) < 4 or
					abs((to_integer(posX)-BALL_RADIUS) - (BRICK_X(i)+BRICK_WIDTH)) < 4
			  )
			  else "00";
	end generate;

	--------------------------------------------------------------------
	-- Hit global
	--------------------------------------------------------------------
	brick_hit <= '1' when brick_hit_vec /= (brick_hit_vec'range => '0') else '0';


	hit_index <=
		 0 when brick_hit_vec(0)='1' else
		 1 when brick_hit_vec(1)='1' else
		 2 when brick_hit_vec(2)='1' else
		 3 when brick_hit_vec(3)='1' else
		 4 when brick_hit_vec(4)='1' else
		 5 when brick_hit_vec(5)='1' else
		 6 when brick_hit_vec(6)='1' else
		 7 when brick_hit_vec(7)='1' else
		 8 when brick_hit_vec(8)='1' else
		 9 when brick_hit_vec(9)='1' else
		 0;
		 
		 --------------------------------------------------------------------
		-- Incrémentation du score sans process
		-- On incrémente de +1 à chaque brick_hit = '1'
		--------------------------------------------------------------------
		next_score <=
			 0 when reset='1' else
			 score + 1 when brick_hit='1' else
			 score;
			 
		next_speed_bonus <=
			 0 when reset='1' else
			 (score / 5) when (score / 5) <= 3 else
			 3;



		 
	--------------------------------------------------------------------
	-- Mise à jour vivantes/mortes
	--------------------------------------------------------------------
	gen_alive : for i in 0 to NBRICKS-1 generate
	begin
		 next_brick_alive_vec(i) <=
			  '1' when reset='1' else
			  '0' when (brick_hit='1' and hit_index=i) else
			  brick_alive_vec(i);
	end generate;

	brick_alive_vec <= next_brick_alive_vec when rising_edge(clk50);



    --------------------------------------------------------------------
    -- Gestion de la mort du joueur
    --------------------------------------------------------------------
    next_player_dead <= 
         '0' when reset = '1' else
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
              (brick_hit = '1' and brick_side_vec(2*hit_index+1 downto 2*hit_index) = "01")

         ) else

         -- rebond sur la raquette : direction = impact + spin
         final_dirX when paddle_hit = '1' else

         -- sinon on garde la direction
         dirX;

    -- Calcul de la direction verticale
    next_dirY <= 
         -1 when reset = '1' else
         -- rebond sur le haut, raquette ou brique
         -dirY when (
              (to_integer(posY) <= FRAME_Y_START + BALL_RADIUS and dirY < 0) or
              (paddle_hit = '1') or
              (brick_hit = '1' and brick_side_vec(2*hit_index+1 downto 2*hit_index) = "10")

         ) else
         dirY;
			
			
			
			--------------------------------------------------------------------
			-- Signe de dirX
			--------------------------------------------------------------------
			sign_dirX <= -1 when dirX < 0 else
							  1 when dirX > 0 else
							  0;

			--------------------------------------------------------------------
			-- Signe de dirY
			--------------------------------------------------------------------
			sign_dirY <= -1 when dirY < 0 else
							  1 when dirY > 0 else
							  0;


    -- Position horizontale
    next_posX <=
		 to_unsigned(BALL_XC_INIT, 10) when reset = '1' else
		 posX when player_dead = '1' else
		 to_unsigned(
			  to_integer(posX)
			  + dirX
			  + (speed_bonus * sign_dirX),
			  10
		 ) when comp = '1' else
		 posX;

    -- Position verticale
    next_posY <=
		 to_unsigned(BALL_YC_INIT, 10) when reset = '1' else
		 posY when player_dead = '1' else
		 to_unsigned(
			  to_integer(posY)
			  + dirY
			  + (speed_bonus * sign_dirY),
			  10
		 ) when comp = '1' else
		 posY;

    --------------------------------------------------------------------
    -- Registres synchrones
    --------------------------------------------------------------------
    posX <= next_posX when rising_edge(clk50);
    posY <= next_posY when rising_edge(clk50);
    dirX <= next_dirX when rising_edge(clk50);
    dirY <= next_dirY when rising_edge(clk50);
    player_dead <= next_player_dead when rising_edge(clk50);
	 score <= next_score when rising_edge(clk50);
	 speed_bonus <= next_speed_bonus when rising_edge(clk50);


	 
	--------------------------------------------------------------------
	-- Conversion score vers digits (BCD)
	--------------------------------------------------------------------
	score_d0 <= std_logic_vector(to_unsigned(score mod 10, 4));
	score_d1 <= std_logic_vector(to_unsigned((score / 10) mod 10, 4));
	score_d2 <= std_logic_vector(to_unsigned((score / 100) mod 10, 4));

		
		--------------------------------------------------------------------
		-- Affichage des 3 digits du score
		--------------------------------------------------------------------
		digit2 : entity work.digit
    port map (
        val      => score_d2,
        posX     => std_logic_vector(to_unsigned(FRAME_X_START+20, 10)),
        posY     => std_logic_vector(to_unsigned(FRAME_Y_START+10, 10)),
        beamX    => beamX,
        beamY    => beamY,
        beamValid=> beamValid,
        red      => "1111",
        green    => "1111",
        blue     => "1111",
        redOut   => rDigit2,
        greenOut => gDigit2,
        blueOut  => bDigit2
    );
	 
	 digit1 : entity work.digit
    port map (
        val      => score_d1,
        posX     => std_logic_vector(to_unsigned(FRAME_X_START+35, 10)),
        posY     => std_logic_vector(to_unsigned(FRAME_Y_START+10, 10)),
        beamX    => beamX,
        beamY    => beamY,
        beamValid=> beamValid,
        red      => "1111",
        green    => "1111",
        blue     => "1111",
        redOut   => rDigit1,
        greenOut => gDigit1,
        blueOut  => bDigit1
    );

	digit0 : entity work.digit
    port map (
        val      => score_d0,
        posX     => std_logic_vector(to_unsigned(FRAME_X_START+50, 10)),
        posY     => std_logic_vector(to_unsigned(FRAME_Y_START+10, 10)),
        beamX    => beamX,
        beamY    => beamY,
        beamValid=> beamValid,
        red      => "1111",
        green    => "1111",
        blue     => "1111",
        redOut   => rDigit0,
        greenOut => gDigit0,
        blueOut  => bDigit0
    );




    --------------------------------------------------------------------
    -- Dessin cadre, paddle, brique et balle
    --------------------------------------------------------------------
	 
   --------------------------------------------------------------------
	-- Dessin pixel brique
	--------------------------------------------------------------------
	gen_draw : for i in 0 to NBRICKS-1 generate
	begin
		 brick_pixel_vec(i) <=
			  '1' when (
					beamValid='1' and brick_alive_vec(i)='1' and
					x >= BRICK_X(i) and x < BRICK_X(i)+BRICK_WIDTH and
					y >= BRICK_Y(i) and y < BRICK_Y(i)+BRICK_HEIGHT
			  )
			  else '0';
	end generate;

	brick_pixel <= '1'
    when brick_pixel_vec /= (brick_pixel_vec'range => '0')
    else '0';


    rSig_int <=
			

	 
		-- Score (digits)
			"1111" when (rDigit2 /= "0000" or gDigit2 /= "0000" or bDigit2 /= "0000") else
			"1111" when (rDigit1 /= "0000" or gDigit1 /= "0000" or bDigit1 /= "0000") else
			"1111" when (rDigit0 /= "0000" or gDigit0 /= "0000" or bDigit0 /= "0000") else

			
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
        -- briques du triangle
			else "1111" when (
				 beamValid='1' and brick_pixel='1'
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
            beamValid='1' and brick_pixel='1'
        )
        else rSig_int;

    bSig_int <= rSig_int;

    red <= rSig_int;
    green <= gSig_int;
    blue <= bSig_int;

end Behavioral;

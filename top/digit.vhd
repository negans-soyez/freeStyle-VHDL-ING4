----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:56:01 09/15/2015 
-- Design Name: 
-- Module Name:    digit - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digit is
    Port ( val : in  STD_LOGIC_VECTOR (3 downto 0);
           posX : in  STD_LOGIC_VECTOR (9 downto 0);
           posY : in  STD_LOGIC_VECTOR (9 downto 0);
           beamX : in  STD_LOGIC_VECTOR (9 downto 0);
           beamY : in  STD_LOGIC_VECTOR (9 downto 0);
			  beamValid : in std_logic;
           red : in  STD_LOGIC_VECTOR (3 downto 0);
           green : in  STD_LOGIC_VECTOR (3 downto 0);
           blue : in  STD_LOGIC_VECTOR (3 downto 0);
           redOut : out  STD_LOGIC_VECTOR (3 downto 0);
           greenOut : out  STD_LOGIC_VECTOR (3 downto 0);
           blueOut : out  STD_LOGIC_VECTOR (3 downto 0) );
end digit;

architecture vhdl of digit is
Type DigitRom is array (0 to 7) of std_logic_vector (0 to 7);

signal Rom_0 : DigitRom := (	"01110000", 
										"10001000", 
										"10011000", 
										"10101000", 
										"11001000", 
										"10001000", 
										"01110000",
										"00000000");

signal Rom_1 : DigitRom := (	"00100000", 
										"01100000", 
										"00100000", 
										"00100000", 
										"00100000", 
										"00100000", 
										"01110000",
										"00000000");

signal Rom_2 : DigitRom := (	"01110000", 
										"10001000", 
										"00001000", 
										"00010000", 
										"00100000", 
										"01000000", 
										"11111000",
										"00000000");

signal Rom_3 : DigitRom := (	"11111000", 
										"00010000", 
										"00100000", 
										"00010000", 
										"00001000", 
										"10001000", 
										"01110000",
										"00000000");

signal Rom_4 : DigitRom := (	"00010000", 
										"00110000", 
										"01010000", 
										"10010000", 
										"11111000", 
										"00010000", 
										"00010000",
										"00000000");

signal Rom_5 : DigitRom := (	"11111000", 
										"10000000", 
										"11110000", 
										"00001000", 
										"00001000", 
										"10001000", 
										"01110000",
										"00000000");

signal Rom_6 : DigitRom := (	"00110000", 
										"01000000", 
										"10000000", 
										"11110000", 
										"10001000", 
										"10001000", 
										"01110000",
										"00000000");
										
signal Rom_7 : DigitRom := (	"11111000", 
										"00001000", 
										"00010000", 
										"00100000", 
										"00100000", 
										"00100000", 
										"00100000",
										"00000000");
										
signal Rom_8 : DigitRom := (	"01110000", 
										"10001000", 
										"10001000", 
										"01110000", 
										"10001000", 
										"10001000", 
										"01110000",
										"00000000");
										
signal Rom_9 : DigitRom := (	"01110000", 
										"10001000", 
										"10001000", 
										"01111000", 
										"00001000", 
										"00010000", 
										"01100000",
										"00000000");
										
signal Rom_A : DigitRom := (	"01110000", 
										"10001000", 
										"10001000", 
										"11111000", 
										"10001000", 
										"10001000", 
										"10001000", 
										"00000000");
										
signal Rom_B : DigitRom := (	"11110000", 
										"10001000", 
										"10001000", 
										"11110000", 
										"10001000", 
										"10001000", 
										"11110000", 
										"00000000");
										
signal Rom_C : DigitRom := (	"01110000", 
										"10001000", 
										"10000000", 
										"10000000", 
										"10000000", 
										"10001000", 
										"01110000",
										"00000000");
										
signal Rom_D : DigitRom := (	"11100000", 
										"10010000", 
										"10001000", 
										"10001000", 
										"10001000", 
										"10010000", 
										"11100000",
										"00000000");
										
signal Rom_E : DigitRom := (	"11111000", 
										"10000000", 
										"10000000", 
										"11110000", 
										"10000000", 
										"10000000", 
										"11111000",
										"00000000");
										
signal Rom_F : DigitRom := (	"11111000", 
										"10000000", 
										"10000000", 
										"11110000", 
										"10000000", 
										"10000000", 
										"10000000", 
										"00000000");

signal newPosX : std_logic_vector(10 downto 0);
signal newPosY : std_logic_vector(10 downto 0);
signal sigValid, romSig : std_logic;

begin

newPosX <= std_logic_vector(('0'&unsigned(beamX))-('0'&unsigned(posX)));
newPosY <= std_logic_vector(('0'&unsigned(beamY))-('0'&unsigned(posY)));
sigValid <= '1' when signed(newPosX)<5 and signed(newPosX)>=0 and signed(newPosY)>=0 and signed(newPosY)<7 and beamValid='1' else '0';
romSig <= '1' when 
						(Rom_0(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0000") or 
						 (Rom_1(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0001") or 
 						 (Rom_2(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0010") or 
 						 (Rom_3(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0011") or 
 						 (Rom_4(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0100") or 
 						 (Rom_5(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0101") or 
 						 (Rom_6(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0110") or 
 						 (Rom_7(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="0111") or 
 						 (Rom_8(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1000") or 
 						 (Rom_9(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1001") or 
 						 (Rom_A(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1010") or 
 						 (Rom_B(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1011") or 
 						 (Rom_C(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1100") or 
 						 (Rom_D(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1101") or 
 						 (Rom_E(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1110") or 
 						 (Rom_F(to_integer(unsigned(newPosY(2 downto 0))))(to_integer(unsigned(newPosX(2 downto 0))))='1' and sigValid='1' and val="1111") 
			else '0';

redOut <= 	red when romSig='1'
				else (others => '0');

greenOut <= green when romSig='1'
				else (others => '0');

blueOut <= 	blue when romSig='1'
				else (others => '0');


end vhdl;


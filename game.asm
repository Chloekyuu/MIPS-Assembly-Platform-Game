#####################################################################
#
# CSCB58 Winter 2023 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Huang Xinzi
# Student Number: 1007623476
# UTorID: huan2534
# Official email: xinzi.huang@mail.utoronto.ca
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 512
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 3 (choose the one the applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. Health/score
# 2. Fail condition
# 3. Win condition
# 4. Shoot enemies
# 5. Enemies shoot back
# 6. Animated sprites
# 7. Moving platforms
#
# Link to video demonstration for final submission:
# - https://youtu.be/eU8JyDfJh8c
#
# Are you OK with us sharing the video with people outside course staff?
# - yes
#
# Any additional information that the TA needs to know:
# - github link (not available yet): https://github.com/Chloekyuu/MIPS-Assembly-Platform-Game.git
#
#####################################################################

.eqv WIDTH		128
.eqv HEIGHT		64
.eqv AREA		8192

.eqv FRAME_BASE		0x10008000
.eqv KEYPRESS_BASE	0xffff0000

.eqv BLACK_COLOUR	0x00000000
.eqv WHITE_COLOUR	0x00ffffff

.eqv REX_COLOUR_MAIN	0x0088c8ff
.eqv REX_COLOUR_MOUTH	0x0058b1ff
.eqv REX_COLOUR_HIT	0x00e7fbff
.eqv REX_SHOOT_COLOUR	0x00007aff

.eqv HP_MAIN_COLOUR	0x00b85249
.eqv HP_FRAME_COLOUR	0x00eda696

.eqv EYE_COLOUR		0x00534d48

.eqv CACTUS_COLOUR	0x0092ed96

.eqv MUSHROOM_MAIN	0x00d20000
.eqv MUSHROOM_DOT	0x00fff1b6
.eqv MUSHROOM_SHOOT	0x00ff9797

.eqv FLAG_COLOUR	0x00f59a23
.eqv STEM_COLOUR	0x00a78266

.eqv PLATFORM_COLOUR	0x00a78266
.eqv GRASS_COLOUR	0x0071A300

#####################################################################
.data

REX_Shot_X:	.word	-1, -1, -1
REX_Shot_Y:	.word	-1, -1, -1
REX_Shot_Sign:	.word	0, 0, 0
REX_HP:		.word	3

Cactus_X:	.word	37, 70, 80, 52
Cactus_Y:	.word	21, 21, 43, 48
Cactus_HP:	.word	3, 3, 3, 3

Mushroom_X:	.word	62, 112, 46
Mushroom_Y:	.word	22, 17, 58
Mushroom_Shot:	.word	62, 112, 46
Mushroom_HP:	.word	2, 2, 2

Platform_X:	.word	56, 52, 34, 105
Platform_Y:	.word	21, 57, 61, 61
Platform_State:	.word	1, 0, 1, 1
Platform_Width:	.word	9, 15, 10, 8

#####################################################################

.text
.global main

####################### INITIALIZE GAME #############################

main:	jal Reset_Screen		# Print the screen black
	jal Draw_Background		# Draw the background
	jal Draw_HP
	jal Draw_Flag
	
	li $s0, 2			# Load the initial position of REX
	li $s1, 10
	li $s2, 0
	
	move $a0, $s0
	move $a1, $s1
	move $a2, $s2
	jal Draw_REX			# Draw the Rex at initial position (2, 4)

######################### GAME MAIN LOOP ############################

Start_Game:
	move $a0, $s0			# First argument: REX x position
	move $a1, $s1			# Second argument: REX y position
	move $a2, $s2			# Pass status as third argument
	jal Check_Keypress		# Check for keypress event
	
	move $s3, $v0			# Store the temporary position in $s3, $s4
	move $s4, $v1
	
	lw $s5, 0($sp)			# pop status off the stack, store in $t5
	addi $sp, $sp, 4		# reclaim space

Skip_Erase_REX:				# Avoid flashing
	bne $s0, $s3, Erase_Old_REX
	bne $s1, $s4, Erase_Old_REX
	beq $s2, $s5, Draw_New_REX

Erase_Old_REX:
	move $a0, $s0			# First argument: REX x position
	move $a1, $s1			# Second argument: REX y position
	move $a2, $s2			# Third argument: status
	jal Erase_REX			# Erase the previous REX
	
Draw_New_REX:
	jal Draw_Platform		# Update the platform

	move $s0, $s3			# Save the current position of REX
	move $s1, $s4
	move $s2, $s5
	
	move $a0, $s0
	move $a1, $s1
	move $a2, $s2
	jal Draw_REX			# Draw a new REX based on its status

Update_Objects:
	move $a0, $s0
	move $a1, $s1
	jal Fix_Platform
	
	jal Update_REX_Shoot		# Check the shot of REX
	jal Update_Cactus		# Check the enemies
	jal Update_Mushroom
	
	lw $s6, REX_HP			# Store the HP before updating
	jal Update_REX_HP		# Update the HP
	lw $t0, REX_HP			# Get the current HP
	beq $t0, $s6, Check_Game_Finish

	jal Erase_HP			# Update the HP of REX
	jal Draw_HP			# Redraw HP

Check_Game_Finish:
	jal Check_Game_Over		# Check the if game over
	
	move $a0, $s0
	move $a1, $s1
	jal Check_Game_Win		# Check if player gets to the desitination
	
	li $v0, 32
	li $a0, 80
	syscall
	
	j Start_Game

############### All functions are inplemented below #################


################### CHECK IF REX IS FALLING #########################
Check_Falling:
	move $t8, $a0			# x
	move $t9, $a1			# y

	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE	# Address Calculations
	
	li $t0, GRASS_COLOUR		# Load colours of valid platforms
	li $t1, PLATFORM_COLOUR

	lw $t2, 4616($t3)		# Get the colour under the left foot of REX
	beq $t2, $t0, Standing_On_Ground
	beq $t2, $t1, Check_On_Which_Platform
	lw $t2, 4632($t3)		# Get the colour under the right foot of REX
	beq $t2, $t0, Standing_On_Ground
	beq $t2, $t1, Check_On_Which_Platform
	
	lw $t2, 5128($t3)		# Get the colour under the left foot of REX
	beq $t2, $t1, Check_Falling_On_Which_Platform
	lw $t2, 5128($t3)		# Get the colour under the right foot of REX
	beq $t2, $t1, Check_Falling_On_Which_Platform
	
	j Falling

Check_On_Which_Platform:
	li $t4, 30			# If y > 30, on level one, not on platform 1
	bgt $t9, $t4, Check_If_On_Platform3
	
On_Platform1:
	addi $t4, $t9, 9
	li $t0, 21
	beq $t4, $t0, Platform_Moving_Up# Special Case when platform at bottom
	li $t0, 14
	beq $t4, $t0, Falling		# Special Case when platform at top
	
	la $t0, Platform_State		# $t0 = Address of the platform state
	lw $t1, 0($t0)
	bgtz $t1, Platform_Moving_Up
	j Falling
	
Check_If_On_Platform3:
	li $t4, 40			# If x > 40, must not on platform 3
	bgt $t8, $t4, Check_If_On_Platform2

On_Platform3:
	addi $t4, $t9, 9
	li $t0, 61
	beq $t4, $t0, Platform_Moving_Up# Special Case when platform at bottom
	li $t0, 53
	beq $t4, $t0, Falling		# Special Case when platform at top

	la $t0, Platform_State		# $t0 = Address of the platform state
	lw $t1, 8($t0)
	bgtz $t1, Platform_Moving_Up
	j Falling

Check_If_On_Platform2:
	li $t4, 90
	bgt $t8, $t4, On_Platform4	# If x > 40, on level one, not on platform 2
	j Standing_On_Ground
	
On_Platform4:
	addi $t4, $t9, 9
	li $t0, 61
	beq $t4, $t0, Platform_Moving_Up# Special Case when platform at bottom
	li $t0, 53
	beq $t4, $t0, Falling		# Special Case when platform at top
	
	la $t0, Platform_State		# $t0 = Address of the platform state
	lw $t1, 12($t0)
	bgtz $t1, Platform_Moving_Up
	j Falling

Platform_Moving_Up:
	move $v0, $t8			# x not change
	addi $v1, $t9, -1		# y - 1 (moving up)
	jr $ra

Check_Falling_On_Which_Platform:
	li $t4, 30			# If y > 30, on level one, not on platform 1
	bgt $t9, $t4, Falling_On_Platform3
	
	la $t0, Platform_State		# $t0 = Address of the platform state
	lw $t1, 0($t0)
	bgtz $t1, Standing_On_Ground
	j Falling
	
Falling_On_Platform3:
	li $t4, 40			# If x > 40, must not on platform 3
	bgt $t8, $t4, Falling_On_Platform2

	la $t0, Platform_State		# $t0 = Address of the platform state
	lw $t1, 8($t0)
	bgtz $t1, Standing_On_Ground
	j Falling

Falling_On_Platform2:
	li $t4, 90
	bgt $t8, $t4, Falling_On_Platform4
	j Falling
	
Falling_On_Platform4:
	la $t0, Platform_State		# $t0 = Address of the platform state
	lw $t1, 12($t0)
	bgtz $t1, Standing_On_Ground
	j Falling

Falling:				# Equivalent as Platform_Moving_Down
	move $v0, $t8			# x not change
	addi $v1, $t9, 1		# y + 1 (falling)
	jr $ra

Standing_On_Ground:
	move $v0, $t8			# x not change
	move $v1, $t9			# y not change
	jr $ra





###################### CHECK KEYPRESS EVENTS ########################

Check_Keypress:				# Determine user keypress
	addi $sp, $sp, -4		
	sw $ra, 0($sp)			# push $ra onto the stack
	
	move $s3, $a0			# x
	move $s4, $a1			# y
	move $t7, $a2			# status

	move $t8, $s3			# Before call check falling, store the (x, y) in $s3, $s4
	move $t9, $s4
	
	jal Check_Falling		# check if the REX is falling
	move $t8, $v0
	move $t9, $v1
	
	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE	# Address Calculations
	
	li $t0, KEYPRESS_BASE
	lw $t1, 0($t0)			# Load key pressed and jump to associated method
	bne $t1, 1, No_Key_Pressed
	lw $t0, 4($t0)			# Load key pressed and jump to associated method
	
	bgt $t9, $s4, REX_Is_Falling	# If y --, REX is falling, skip jump

	beq $t0, 0x77, W_Pressed_Can_Jump
	
REX_Is_Falling:
	beq $t0, 0x61, A_Pressed
	beq $t0, 0x64, D_Pressed
	beq $t0, 0x73, S_Pressed
	beq $t0, 0x77, W_Pressed_Cannot_Jump
	beq $t0, 0x70, P_Pressed
	beq $t0, 0x20, Space_Pressed

No_Key_Pressed:
	lw $ra, 0($sp)			# pop $ra off the stack
	sw $t7, 0($sp)			# push status onto the stack
	move $v0, $t8			# x no change
	move $v1, $t9			# y no change
	jr $ra				# jump back to the main loop

##################### A PRESSED: MOVE LEFT ##########################
A_Pressed:
	beqz $t7, Up_REX_Right_To_Left
	li $t0, 2
	beq $t7, $t0, Up_Left_REX_Go_Left
	j No_Key_Pressed		# if down, cannot move
	
Up_REX_Right_To_Left:
	li $t7, 2
	move $v0, $t8			# x no change
	move $v1, $t9			# y no change
	j Go_Left

Down_REX_Right_To_Left:
	li $t7, 3
	move $v0, $t8			# x no change
	move $v1, $t9			# y no change
	j Go_Left

Up_Left_REX_Go_Left:
	addi $v1, $t9, -2		# y - 2
	beqz $t8, No_Key_Pressed	# if no place to go, no effect
	li $t0, BLACK_COLOUR

	addi $t3, $t3, -4
	lw $t1, 0($t3)			# area in front of REX nose
	bne $t0, $t1, No_Key_Pressed
	
	addi $t3, $t3, 1024
	lw $t1, 0($t3)			# area in front of REX jaw
	bne $t0, $t1, No_Key_Pressed
	
	addi $t3, $t3, 1540
	lw $t1, 0($t3)			# area in front of REX hand
	bne $t0, $t1, No_Key_Pressed
	
	addi $v0, $t8, -1		# x - 1 (move left)
	beqz $v0, Go_Left
	
	addi $t3, $t3, -4
	lw $t1, 0($t3)			# area in front of REX nose
	bne $t0, $t1, Go_Left
	
	addi $t3, $t3, -1540
	lw $t1, 0($t3)			# area in front of REX jaw
	bne $t0, $t1, Go_Left
	
	addi $t3, $t3, -1024
	lw $t1, 0($t3)			# area in front of REX hand
	bne $t0, $t1, Go_Left
	
	addi $v0, $v0, -1		# x - 1 (move left)
	beqz $v0, Go_Left
	
	addi $t3, $t3, -4
	lw $t1, 0($t3)			# area in front of REX nose
	bne $t0, $t1, Go_Left
	
	addi $t3, $t3, 1024
	lw $t1, 0($t3)			# area in front of REX jaw
	bne $t0, $t1, Go_Left
	
	addi $t3, $t3, 1540
	lw $t1, 0($t3)			# area in front of REX hand
	bne $t0, $t1, Go_Left
	
	addi $v0, $v0, -1		# x - 1 (move left)
	
	j Go_Left

Down_Left_REX_Go_Left:
	blt $t8, $t0, No_Key_Pressed
	li $t0, BLACK_COLOUR

	addi $t3, $t3, -4
	lw $t1, 0($t3)			# area in front of REX nose
	bne $t0, $t1, No_Key_Pressed
	
	addi $t3, $t3, 1024
	lw $t1, 0($t3)			# area in front of REX jaw
	bne $t0, $t1, No_Key_Pressed
	
	addi $t3, $t3, 1540
	lw $t1, 0($t3)			# area in front of REX hand
	bne $t0, $t1, No_Key_Pressed
	
	addi $v0, $t8, -1		# x - 1 (move left)

Go_Left:
	lw $ra, 0($sp)			# pop $ra off the stack
	sw $t7, 0($sp)			# push status onto the stack
	jr $ra

####################### D PRESSED: MOVE RIGHT #######################
D_Pressed:
	beqz $t7, Up_Right_REX_Go_Right
	li $t0, 2
	beq $t7, $t0, Up_Left_REX_To_Right
	j No_Key_Pressed		# if down, cannot move
	
Up_Right_REX_Go_Right:
	addi $v1, $t9, -2		# y - 2
	
	li $t2, 119
	beq $t8, $t2, No_Key_Pressed	# right most of the screen
	
	li $t0, BLACK_COLOUR

	lw $t1, 36($t3)			# area in front of REX nose
	bne $t0, $t1, No_Key_Pressed
	
	addi $t3, $t3, 1024
	lw $t1, 36($t3)			# area in front of REX jaw
	bne $t0, $t1, No_Key_Pressed
	
	addi $t3, $t3, 1536
	lw $t1, 32($t3)			# area in front of REX hand
	bne $t0, $t1, No_Key_Pressed
	
	addi $v0, $t8, 1		# x + 1 (move right)
	beq $v0, $t2, Go_Right

	lw $t1, 36($t3)			# area in front of REX hand
	bne $t0, $t1, Go_Right
	
	addi $t3, $t3, -1536
	lw $t1, 40($t3)			# area in front of REX jaw
	bne $t0, $t1, Go_Right
	
	addi $t3, $t3, -1024
	lw $t1, 40($t3)			# area in front of REX nose
	bne $t0, $t1, Go_Right
	
	addi $v0, $v0, 1		# x + 1 (move left)
	beq $v0, $t2, Go_Right
	
	lw $t1, 44($t3)			# area in front of REX nose
	bne $t0, $t1, Go_Right
	
	addi $t3, $t3, 1024
	lw $t1, 44($t3)			# area in front of REX jaw
	bne $t0, $t1, Go_Right
	
	addi $t3, $t3, 1536
	lw $t1, 40($t3)			# area in front of REX hand
	bne $t0, $t1, Go_Right
	
	addi $v0, $v0, 1		# x + 1 (move left)
	j Go_Right

Down_REX_Right_Go_Right:
	li $t0, 116
	beq $t8, $t0, No_Key_Pressed
	addi $v0, $t8, 1		# x + 1 (move right)
	j Go_Right

Up_Left_REX_To_Right:
	li $t7, 0
	move $v0, $t8			# x no change
	move $v1, $t9			# y no change
	j Go_Right

Down_Left_REX_To_Right:
	li $t7, 1
	move $v0, $t8			# x no change
	move $v1, $t9			# y no change

Go_Right:
	lw $ra, 0($sp)			# pop $ra off the stack
	sw $t7, 0($sp)			# push status onto the stack
	jr $ra

######################## S PRESSED: GO DOWN #########################
S_Pressed:
	beqz $t7, Right_REX_Go_Down
	li $t0, 2
	beq $t7, $t0, Left_REX_Go_Down
	
	j No_Key_Pressed		# if down, cannot go down again

Right_REX_Go_Down:
	li $t4, 115
	bgt $t8, $t4, No_Key_Pressed
	addi $t3, $t3, 1536
	
	li $t4, 4
	li $t2, GRASS_COLOUR

Check_Right_Down_Space:
	lw $t1, 32($t3)			# Check if space in front of REX
	beq $t2, $t1, Go_Down		# If if grass, no effect
	lw $t1, 36($t3)
	beq $t2, $t1, Go_Down
	lw $t1, 40($t3)
	beq $t2, $t1, Go_Down
	lw $t1, 44($t3)
	beq $t2, $t1, Go_Down
	
	addi $t4, $t4, -1
	addi $t3, $t3, 512
	
	bgtz $t4, Check_Right_Down_Space

	li $t7, 1
	j Go_Down
	
Left_REX_Go_Down:
	li $t4, 3
	blt $t8, $t4, No_Key_Pressed
	addi $t3, $t3, 1536
	
	li $t4, 4
	li $t0, BLACK_COLOUR
	li $t2, GRASS_COLOUR

Check_Left_Down_Space:
	lw $t1, -4($t3)			# Check if space in front of REX
	beq $t2, $t1, Go_Down		# If if grass, no effect
	bne $t0, $t1, Go_Down		# else if not Black, got hit
	lw $t1, -8($t3)
	beq $t2, $t1, Go_Down
	bne $t0, $t1, Go_Down
	lw $t1, -12($t3)
	beq $t2, $t1, Go_Down
	bne $t0, $t1, Go_Down
	lw $t1, -16($t3)
	beq $t2, $t1, Go_Down
	bne $t0, $t1, Go_Down
	
	addi $t4, $t4, -1
	addi $t3, $t3, 512
	
	bgtz $t4, Check_Left_Down_Space
	li $t7, 3
	
Go_Down:
	move $v0, $t8			# x no change
	move $v1, $t9			# y no change
	lw $ra, 0($sp)			# pop $ra off the stack
	sw $t7, 0($sp)			# push status onto the stack
	jr $ra

######################### W PRSSED: JUMP ############################
W_Pressed_Can_Jump:
	li $t5, 4			# Additional space to jump
	beqz $t7, Right_REX_Jump
	li $t0, 2
	beq $t7, $t0, Left_REX_Jump

W_Pressed_Cannot_Jump:
	li $t0, 1
	beq $t7, $t0, Right_REX_Go_Up
	li $t0, 3
	beq $t7, $t0, Left_REX_Go_Up
	j No_Key_Pressed		# if down, cannot go down again

Right_REX_Jump:
	sub $t9, $t9, $t5
	addi $t3, $t3, -3072		# Address update
	j Up_Right_REX_Go_Right

Left_REX_Jump:
	sub $t9, $t9, $t5
	addi $t3, $t3, -3072		# Address update
	j Up_Left_REX_Go_Left

Right_REX_Go_Up:
	li $t7, 0			# Switch to up status
	move $v1, $t9			# y no change
	move $v0, $t8			# x no change
	j Go_Up

Left_REX_Go_Up:
	li $t7, 2			# Switch to up status
	move $v1, $t9			# y no change
	move $v0, $t8			# x no change

Go_Up:
	lw $ra, 0($sp)			# pop $ra off the stack
	sw $t7, 0($sp)			# push status onto the stack
	jr $ra

###################### P PRSEED: RESTART GAME #######################
P_Pressed:
	la $t0, REX_Shot_X		# Reset the shot for REX
	li $t4, -1
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	
	la $t0, Mushroom_Shot		# Reset the shot for mushroom
	li $t4, 62
	sw $t4, 0($t0)
	li $t4, 112
	sw $t4, 4($t0)
	li $t4, 46
	sw $t4, 8($t0)
	
	la $t0, REX_HP			# Reset the HP for REX
	li $t4, 3
	sw $t4, 0($t0)
	
	la $t0, Cactus_HP		# Reset the HP for cactis
	li $t4, 3
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	sw $t4, 12($t0)
	
	la $t0, Mushroom_HP		# Reset the HP for mushroom
	li $t4, 2
	sw $t4, 0($t0)
	sw $t4, 4($t0)
	sw $t4, 8($t0)
	
	la $t0, Platform_Y		# Reset the platform position
	li $t4, 21
	sw $t4, 0($t0)
	li $t4, 61
	sw $t4, 8($t0)
	sw $t4, 12($t0)
	
	la $t0, Platform_State		# Reset the platform state
	li $t4, 1
	sw $t4, 0($t0)
	sw $t4, 8($t0)
	sw $t4, 12($t0)
	
	lw $ra, 0($sp)			# pop $ra off the stack
	addi $sp, $sp, 4
	la $ra, main
	jr $ra

####################### SPACE PRESSED: SHOOT ########################
Space_Pressed:
	li $t1, PLATFORM_COLOUR

	lw $t2, 4616($t3)		# Get the colour under the left foot of REX
	beq $t2, $t1, Load_Shot_Position
	lw $t2, 4632($t3)		# Get the colour under the right foot of REX
	beq $t2, $t1, Load_Shot_Position
	
	move $t8, $s3
	move $t9, $s4

Load_Shot_Position:
	la $t0, REX_Shot_X
	la $t1, REX_Shot_Y
	la $t2, REX_Shot_Sign
	li $t6, 3
	
Available_Shot:
	lw $t4, 0($t0)			# x position of the first shot
	
	li $t5, 128
	beq $t4, $t5, Able_To_Shoot	# If x == -1, available
	li $t5, -1
	beq $t4, $t5, Able_To_Shoot	# If x == 128, available
	
	addi $t6, $t6, -1
	beqz $t6, No_Key_Pressed	# If i == 0, no available shot, space no effect
	
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	addi $t2, $t2, 4
	j Available_Shot
	
Able_To_Shoot:
	beqz $t7, Right_Up_REX_Shot
	li $t5, 1
	beq $t7, $t5, Right_Down_REX_Shot
	li $t5, 2
	beq $t7, $t5, Left_Up_REX_Shot
	j Left_Down_REX_Shot
	
Right_Up_REX_Shot:
	addi $t4, $t8, 7		# Set the shot x psotion
	sw $t4, 0($t0)
	addi $t4, $t9, 2		# Set the shot y psotion
	sw $t4, 0($t1)
	li $t4, 1
	sw $t4, 0($t2)			# Set the shot direction
	j Shoot_End

Right_Down_REX_Shot:
	addi $t4, $t8, 10		# Set the shot x psotion
	sw $t4, 0($t0)
	addi $t4, $t9, 5		# Set the shot y psotion
	sw $t4, 0($t1)
	li $t4, 1
	sw $t4, 0($t2)			# Set the shot direction
	j Shoot_End

Left_Up_REX_Shot:
	addi $t4, $t8, 1		# Set the shot x psotion
	sw $t4, 0($t0)
	addi $t4, $t9, 2		# Set the shot y psotion
	sw $t4, 0($t1)
	li $t4, -1
	sw $t4, 0($t2)			# Set the shot direction
	j Shoot_End

Left_Down_REX_Shot:
	addi $t4, $t8, -2		# Set the shot x psotion
	sw $t4, 0($t0)
	addi $t4, $t9, 5		# Set the shot y psotion
	sw $t4, 0($t1)
	li $t4, -1
	sw $t4, 0($t2)			# Set the shot direction

Shoot_End:
	move $a0, $t8
	move $a1, $t9
	move $a2, $t7
	jal Draw_REX_Shoot		# Already redraw the REX here
	
	jal Draw_Platform		# Update the platform
	
	la $t0, Update_Objects		# Only need to update the rest objects
	sw $t0, 0($sp)			# change $ra on the stack
	j No_Key_Pressed





######################### DRAW BACKGROUND ###########################

Draw_Background:
	li $t8, 0
	li $t9, 21			# Top left-most position (0, 21)
	
	mul $t3, $t9, 512		# $t3 = address of x
	addi $t3, $t3, FRAME_BASE	# Address calculations
	
	li $t0, GRASS_COLOUR		# Load Colour
	li $t4, 9

########################## DRAW LEVEL 1 #############################
Level1:
	addi $t4, $t4, -1		# i --
	addi $t3, $t3, 384
	li $t5, 20			# j = 20; j > 0; j --
	
Level1_High:
	sw $t0, 0($t3)			# Paint the pixel with colour $t0
	addi $t3, $t3, 4		# next pixel
	addi $t5, $t5, -1		# j --
	bgtz $t5, Level1_High
	
	addi $t3, $t3, 48		# Move to next line
	li $t5, 5
	beqz $t4, Draw_Level_2		# If i == 0, done painting
	blt $t4, $t5, Level1		# If i < 4, only high level not finished
	
	addi $t3, $t3, 2052		# Move 4 rows down to draw medium ground
	
Level1_Medium:
	sw $t0, 60($t3)			# first obstacle
	sw $t0, 64($t3)
	sw $t0, 68($t3)
	sw $t0, 72($t3)
	
	sw $t0, 184($t3)		# second obstacle
	sw $t0, 188($t3)
	sw $t0, 192($t3)
	sw $t0, 196($t3)
	sw $t0, 200($t3)
	sw $t0, 204($t3)
	sw $t0, 208($t3)
	sw $t0, 212($t3)
	sw $t0, 216($t3)
	sw $t0, 220($t3)
	sw $t0, 224($t3)
	sw $t0, 228($t3)
	sw $t0, 232($t3)
	sw $t0, 236($t3)
	sw $t0, 240($t3)
	sw $t0, 244($t3)
	sw $t0, 248($t3)
	sw $t0, 252($t3)
	sw $t0, 256($t3)
	sw $t0, 260($t3)

	sw $t0, 344($t3)		# third obstacle
	sw $t0, 348($t3)
	sw $t0, 352($t3)
	sw $t0, 356($t3)
	sw $t0, 360($t3)
	sw $t0, 364($t3)
	sw $t0, 368($t3)
	sw $t0, 372($t3)
	sw $t0, 376($t3)
	sw $t0, 380($t3)
	sw $t0, 384($t3)
	
	addi $t3, $t3, -2052		# Move up 4 rows
	
	li $t5, 7
	blt $t4, $t5, Level1		# If i < 6, only obstacles not finished
	
	addi $t3, $t3, 4096		# row + 8
	li $t5, 116

Level1_Ground:
	sw $t0, 0($t3)			# Paint the pixel with colour $t0
	addi $t3, $t3, 4		# next pixel
	addi $t5, $t5, -1		# j --
	bgtz $t5, Level1_Ground

	addi $t3, $t3, -4560		# Move up
	
	j Level1

########################### DRAW LEVEL 2 ############################
Draw_Level_2:
	li $t9, 52			# Top left-most position (0, 50)
	mul $t3, $t9, 512		# $t3 = address of x
	addi $t3, $t3, FRAME_BASE	# Address calculations
	li $t4, 10
	
Level2:
	addi $t4, $t4, -1		# i --
	sw $t0, 96($t3)			# first obstacle
	sw $t0, 100($t3)
	sw $t0, 104($t3)
	sw $t0, 108($t3)
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	
	sw $t0, 316($t3)		# second obstacle
	sw $t0, 320($t3)
	sw $t0, 324($t3)
	sw $t0, 328($t3)
	sw $t0, 332($t3)
	sw $t0, 336($t3)
	sw $t0, 340($t3)
	sw $t0, 344($t3)
	sw $t0, 348($t3)
	sw $t0, 352($t3)
	sw $t0, 356($t3)
	sw $t0, 360($t3)
	sw $t0, 364($t3)
	sw $t0, 368($t3)
	sw $t0, 372($t3)
	sw $t0, 376($t3)
	sw $t0, 380($t3)
	sw $t0, 384($t3)
	sw $t0, 388($t3)
	sw $t0, 392($t3)
	sw $t0, 396($t3)
	sw $t0, 400($t3)
	sw $t0, 404($t3)
	sw $t0, 408($t3)

	addi $t3, $t3, 512		# Move to next line
	
	li $t5, 8
	beqz $t4, Level2_end		# If i == 0, done painting

	blt $t4, $t5, Level2		# If i < 6, only obstacles not finished
	
	addi $t3, $t3, 4608		# row + 8
	
	sw $t0, 96($t3)			# first obstacle
	sw $t0, 100($t3)
	sw $t0, 104($t3)
	sw $t0, 108($t3)
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	
	li $t5, 12
	
Level2_Ground1:
	sw $t0, 0($t3)			# Paint the pixel with colour $t0
	addi $t3, $t3, 4		# next pixel
	addi $t5, $t5, -1		# j --
	bgtz $t5, Level2_Ground1

	addi $t3, $t3, 132
	li $t5, 58
	
Level2_Ground2:
	sw $t0, 0($t3)			# Paint the pixel with colour $t0
	addi $t3, $t3, 4		# next pixel
	addi $t5, $t5, -1		# j --
	bgtz $t5, Level2_Ground2
	
	addi $t3, $t3, 52
	li $t5, 12
	
Level2_Ground3:
	sw $t0, 0($t3)			# Paint the pixel with colour $t0
	addi $t3, $t3, 4		# next pixel
	addi $t5, $t5, -1		# j --
	bgtz $t5, Level2_Ground3
	
	addi $t3, $t3, -5120		# Move up
	j Level2

Level2_end:
	jr $ra




########################### FIX PLATFORM ############################
Fix_Platform:
	li $t9, 21			# Top left-most position (0, 21)
	mul $t3, $t9, 512
	addi $t3, $t3, FRAME_BASE	# Address calculations
	
	li $t0, GRASS_COLOUR		# Load Colour

	move $t8, $a0
	move $t9, $a1

	li $t4, 40
	bgt $t9, $t4, Fix_Level_2
	
Fix_Level_1:
	li $t4, 25
	blt $t8, $t4, Fix_Level1_Obstacle1
	
	li $t4, 70
	blt $t8, $t4, Fix_Level1_Obstacle2
	
	li $t4, 114
	li $t5, 11
	bge $t8, $t4, Fix_Level1_Obstacle3
	
	sw $t0, 384($t3)		# third obstacle
	sw $t0, 388($t3)
	addi $t3, $t3, 512
	sw $t0, 384($t3)
	addi $t3, $t3, 2052
	sw $t0, 344($t3)
	sw $t0, 348($t3)
	addi $t3, $t3, 512
	sw $t0, 344($t3)
	j Fix_Platform_End

Fix_Level1_Obstacle3:
	sw $t0, 452($t3)
	sw $t0, 456($t3)
	sw $t0, 460($t3)
	addi $t3, $t3, 512
	addi $t5, $t5, -1		# i --
	beqz $t5, Fix_Platform_End
	j Fix_Level1_Obstacle3
	
Fix_Level1_Obstacle1:
	addi $t3, $t3, 2560
	sw $t0, 64($t3)			# first obstacle
	sw $t0, 68($t3)
	sw $t0, 72($t3)
	sw $t0, 76($t3)
	addi $t3, $t3, 512
	sw $t0, 64($t3)
	sw $t0, 76($t3)
	j Fix_Platform_End

Fix_Level1_Obstacle2:
	addi $t3, $t3, 2564
	sw $t0, 184($t3)		# second obstacle
	sw $t0, 188($t3)
	sw $t0, 256($t3)
	sw $t0, 260($t3)
	addi $t3, $t3, 512
	sw $t0, 184($t3)		# second obstacle
	sw $t0, 260($t3)
	j Fix_Platform_End

Fix_Level_2:
	li $t4, 60
	blt $t8, $t4, Fix_Level2_Obstacle1
	li $t4, 95
	blt $t8, $t4, Fix_Level2_Obstacle2
	j Fix_Level2_Obstacle3

Fix_Level2_Obstacle1:
	li $t9, 62
	mul $t3, $t9, 512
	addi $t3, $t3, FRAME_BASE	# Address calculations
	
	sw $t0, 44($t3)
	sw $t0, 100($t3)
	addi $t3, $t3, 512
	sw $t0, 44($t3)
	sw $t0, 100($t3)
	
	li $t9, 52
	mul $t3, $t9, 512
	addi $t3, $t3, FRAME_BASE	# Address calculations
	
	sw $t0, 96($t3)
	sw $t0, 100($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 100($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 100($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 100($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 100($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 100($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 512
	sw $t0, 96($t3)
	sw $t0, 124($t3)
	addi $t3, $t3, 1024
	sw $t0, 180($t3)
	
	j Fix_Platform_End
	
Fix_Level2_Obstacle2:
	li $t9, 52
	mul $t3, $t9, 512
	addi $t3, $t3, FRAME_BASE	# Address calculations
	
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	addi $t3, $t3, 512
	sw $t0, 316($t3)
	sw $t0, 320($t3)
	
	j Fix_Platform_End
	
Fix_Level2_Obstacle3:
	li $t9, 52
	mul $t3, $t9, 512
	addi $t3, $t3, FRAME_BASE	# Address calculations
	
	sw $t0, 384($t3)
	sw $t0, 388($t3)
	sw $t0, 392($t3)
	sw $t0, 396($t3)
	sw $t0, 400($t3)
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 404($t3)
	sw $t0, 408($t3)
	addi $t3, $t3, 512
	sw $t0, 408($t3)
	addi $t3, $t3, 1024
	sw $t0, 464($t3)
	
Fix_Platform_End:
	jr $ra
	



######################### UPDATE PLATFORM ###########################
Draw_Platform:
	addi $sp, $sp, -4		# save $ra on the stack
	sw $ra, 0($sp)
	
	la $t1, Platform_State		# Address of Platform_State
	la $t6, Platform_X		# Address of Platform_X
	la $t7, Platform_Y		# Address of Platform_Y

	lw $t2, 0($t1)			# Status of the first platform
	lw $t8, 0($t6)			# The first platform's x position
	lw $t9, 0($t7)			# y position of the first platform

	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t4, 9			# Platform width
	li $t0, BLACK_COLOUR		# Load the back ground colour
	jal Paint_Platform		# Erase the old platform
	
	li $t5, 21			# If platform at position y = 19, cannot move down
	beq $t9, $t5, Platform1_Move_Up
	li $t5, 14			# If platform at position y = 13, cannot move up
	beq $t9, $t5, Platform1_Move_Down
	bgtz $t2, Platform1_Move_Up	# If state = 1, continue moving up
	bltz $t2, Platform1_Move_Down	# If state = -1, continue moving down
	
Platform1_Move_Up:
	li $t5, 1
	sw $t5, 0($t1)			# State of platform 1 = 1 (move up)
	addi $t9, $t9, -1		# y -- (move up)
	sw $t9, 0($t7)			# Update the y position
	j Redraw_Platform1
	
Platform1_Move_Down:
	li $t5, -1
	sw $t5, 0($t1)			# State of platform 1 = -1 (move down)
	addi $t9, $t9, 1		# y ++ (move down)
	sw $t9, 0($t7)			# Update the y position
	
Redraw_Platform1:
	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t4, 9			# Platform width
	li $t0, PLATFORM_COLOUR		# Load the back ground colour
	jal Paint_Platform		# Erase the old platform
	
Update_Platform2:
	lw $t8, 4($t6)			# x position of the platform
	lw $t9, 4($t7)			# y position of the platform
	
	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t4, 15			# Platform width
	jal Paint_Platform		# Erase the old platform
	
Update_Platform3:
	lw $t2, 8($t1)			# Status of the platform
	lw $t8, 8($t6)			# x position of the platform
	lw $t9, 8($t7)			# y position of the platform
	
	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t0, BLACK_COLOUR		# Load the back ground colour
	li $t4, 8			# Platform width
	jal Paint_Platform		# Erase the old platform
	
	li $t5, 61			# If platform at position y = 63, move up
	beq $t9, $t5, Platform3_Move_Up
	li $t5, 53			# If platform at position y = 53, move down
	beq $t9, $t5, Platform3_Move_Down
	bgtz $t2, Platform3_Move_Up	# If state = 1, continue moving up
	bltz $t2, Platform3_Move_Down	# If state = 1, continue moving down

Platform3_Move_Up:
	li $t5, 1
	sw $t5, 8($t1)			# State of platform 1 = 1 (move up)
	addi $t9, $t9, -1		# y -- (move up)
	sw $t9, 8($t7)			# Update the y position
	j Redraw_Platform3

Platform3_Move_Down:
	li $t5, -1
	sw $t5, 8($t1)			# State of platform 1 = 1 (move down)
	addi $t9, $t9, 1		# y ++ (move down)
	sw $t9, 8($t7)			# Update the y position

Redraw_Platform3:
	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t4, 8			# Platform width
	li $t0, PLATFORM_COLOUR		# Load the back ground colour
	jal Paint_Platform		# Erase the old platform

Update_Platform4:
	lw $t2, 12($t1)			# Status of the platform
	lw $t8, 12($t6)			# x position of the platform
	lw $t9, 12($t7)			# y position of the platform

	li $t4, 8			# Platform width
	
	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t0, BLACK_COLOUR		# Load the back ground colour
	jal Paint_Platform		# Erase the old platform
	
	li $t5, 61			# If platform at position y = 61, cannot move down
	beq $t9, $t5, Platform4_Move_Up
	li $t5, 53			# If platform at position y = 53, cannot move up
	beq $t9, $t5, Platform4_Move_Down
	bgtz $t2, Platform4_Move_Up	# If state = 1, continue moving up
	bltz $t2, Platform4_Move_Down	# If state = -1, continue moving down
	
Platform4_Move_Up:
	li $t5, 1
	sw $t5, 12($t1)			# State of platform 1 = 1 (move up)
	addi $t9, $t9, -1		# y -- (move up)
	sw $t9, 12($t7)			# Update the y position
	j Redraw_Platform4

Platform4_Move_Down:
	li $t5, -1
	sw $t5, 12($t1)			# State of platform 1 = 1 (move down)
	addi $t9, $t9, 1		# y ++ (move down)
	sw $t9, 12($t7)			# Update the y position

Redraw_Platform4:
	mul $t3, $t9, 512		# Calculate the address for the first platform
	mul $t5, $t8, 4
	add $t3, $t3, $t5
	addi $t3, $t3, FRAME_BASE	# Store in $t3
	
	li $t0, PLATFORM_COLOUR		# Load the back ground colour
	li $t4, 8			# Platform width
	jal Paint_Platform		# Erase the old platform

	lw $ra, 0($sp)			# pop $ra off the stack
	addi $sp, $sp, 4		# reclaim space
	jr $ra

Paint_Platform:
	li $t5, 0
Paint_Platform_Row1:
	sw $t0, 0($t3)			# Paint
	addi $t3, $t3, 4
	addi $t5, $t5, 1		# j ++
	ble $t5, $t4, Paint_Platform_Row1
	addi $t3, $t3, -4
	jr $ra
	



####################### PAINT SCREEN TO BLACK #######################
Reset_Screen:
	li $t3, FRAME_BASE		# Store the base address in $t3
	li $t0, BLACK_COLOUR		# Background colour
	li $t1, 8192			# Total pixels in screen

Print_Screen_BLACK:
	sw $t0, 0($t3)			# Paint
	addi $t3, $t3, 4
	addi $t1, $t1, -1		# i --
	bgtz $t1, Print_Screen_BLACK
	jr $ra




######################### DRAW/ERASE REX HP #########################
Draw_HP:
	li $t0, HP_MAIN_COLOUR		# Load colours
	li $t1, HP_FRAME_COLOUR
	li $t3, FRAME_BASE		# Store the base address in $t3
	addi $t3, $t3, 1500		# Address of the third HP
	lw $t2, REX_HP			# Get REX current HP
	bgtz $t2, Draw_HP_Loop

Erase_HP:
	li $t0, BLACK_COLOUR		# Load colours
	li $t1, BLACK_COLOUR
	li $t3, FRAME_BASE		# Store the base address in $t3
	addi $t3, $t3, 1500		# Address of the third HP
	lw $t2, REX_HP			# Get REX current HP
	addi $t2, $t2, 1

Draw_HP_Loop:
	addi $t2, $t2, -1		# i --
	
	sw $t1, 4($t3)			# row 1
	sw $t1, 8($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)

	addi $t3, $t3, 512		# row 2
	sw $t1, 4($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	
	addi $t3, $t3, 512		# row 3
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	
	addi $t3, $t3, 512		# row 4
	sw $t0, 12($t3)
	
	addi $t3, $t3, -1568		# draw previous HP
	
	bgtz $t2, Draw_HP_Loop		# i > 0, continue to draw
	
	jr $ra




############################## DRAW FLAG ############################
Draw_Flag:
	li $t8, 2			# x
	li $t9, 53			# y
	
	li $t0, STEM_COLOUR		# Load colours
	li $t1, FLAG_COLOUR
	
	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE	# Address Calculations
	
	sw $t0, 0($t3)			# row 1
	sw $t1, 4($t3)
	
	addi $t3, $t3, 512		# row 2
	sw $t0, 0($t3)
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	addi $t3, $t3, 512		# row 3
	sw $t0, 0($t3)
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	
	addi $t3, $t3, 512		# row 4
	sw $t0, 0($t3)
	sw $t1, 4($t3)
	
	addi $t3, $t3, 512		# row 5
	sw $t0, 0($t3)
	addi $t3, $t3, 512		# row 6
	sw $t0, 0($t3)
	addi $t3, $t3, 512		# row 7
	sw $t0, 0($t3)
	addi $t3, $t3, 512		# row 8
	sw $t0, 0($t3)
	addi $t3, $t3, 512		# row 9
	sw $t0, 0($t3)
	jr $ra

#####################################################################

########################## DRAW/ERASE REX ###########################

Draw_REX:
	move $t7, $a2
	beqz $t7, Draw_Right_REX
	li $t4, 1
	beq $t4, $t7, Draw_Right_REX
	li $t4, 2
	beq $t4, $t7, Draw_Left_REX
	li $t4, 3
	beq $t4, $t7, Draw_Left_REX

Draw_REX_Hit:
	move $t7, $a2
	beqz $t7, Draw_Right_REX_Hit
	li $t4, 1
	beq $t4, $t7, Draw_Right_REX_Hit
	li $t4, 2
	beq $t4, $t7, Draw_Left_REX_Hit
	li $t4, 3
	beq $t4, $t7, Draw_Left_REX_Hit

Erase_REX:
	move $t7, $a2
	beqz $t7, Erase_Right_REX
	li $t4, 1
	beq $t4, $t7, Erase_Right_REX
	li $t4, 2
	beq $t4, $t7, Erase_Left_REX
	li $t4, 3
	beq $t4, $t7, Erase_Left_REX

Draw_Right_REX:
	li $t0, EYE_COLOUR
	li $t1, REX_COLOUR_MAIN
	li $t2, REX_COLOUR_MOUTH
	j Load_Right_REX_Position

Draw_Right_REX_Hit:
	li $t0, EYE_COLOUR
	li $t1, REX_COLOUR_HIT
	li $t2, REX_COLOUR_MOUTH
	j Load_Right_REX_Position

Erase_Right_REX:
	li $t0, BLACK_COLOUR
	li $t1, BLACK_COLOUR
	li $t2, BLACK_COLOUR

Load_Right_REX_Position:
	# Use t8 and t9 for initial position (x, y) of the rex
	move $t8, $a0
	move $t9, $a1
	# Address Calculations
	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE
	
	li $t6, 1
	beq $t7, $t6, Draw_Right_Down_REX

######################### PAINT RIGHT REX ###########################

Draw_Right_REX_End:
	sw $t1, 20($t3)			# row 1
	sw $t0, 24($t3)			# eye
	sw $t1, 28($t3)
	sw $t1, 32($t3)
	
	addi $t3, $t3, 512		# row 2
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	sw $t1, 28($t3)
	sw $t1, 32($t3)
	
	addi $t3, $t3, 512		# row 3
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	sw $t2, 28($t3)
	sw $t2, 32($t3)
	addi $t3, $t3, -1024
	
Draw_Right_Down_REX:
	addi $t3, $t3, 1536		# row 4
	li $t4, BLACK_COLOUR
	sw $t1, 0($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	sw $t4, 28($t3)
	sw $t4, 32($t3)
	
	addi $t3, $t3, 512		# row 5
	sw $t1, 0($t3)
	sw $t1, 4($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	
	addi $t3, $t3, 512		# row 6
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	sw $t1, 28($t3)
	
	addi $t3, $t3, 512		# row 7
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	
	addi $t3, $t3, 512		# row 8
	sw $t1, 8($t3)
	sw $t1, 20($t3)
	
	addi $t3, $t3, 512		# row 9
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	
	beq $t7, $t6, Draw_Right_Down_REX_End
	jr $ra

Draw_Right_Down_REX_End:
	addi $t3, $t3, -1024		# row 7
	li $t4, BLACK_COLOUR
	sw $t4, 24($t3)
	sw $t1, 28($t3)
	sw $t4, 36($t3)
	sw $t4, 40($t3)
	sw $t4, 44($t3)
	
	addi $t3, $t3, -512		# row 6
	sw $t1, 32($t3)
	sw $t1, 36($t3)
	sw $t2, 40($t3)
	sw $t2, 44($t3)
	
	addi $t3, $t3, -512		# row 5
	sw $t1, 28($t3)
	sw $t1, 32($t3)
	sw $t1, 36($t3)
	sw $t1, 40($t3)
	sw $t1, 44($t3)
	
	addi $t3, $t3, -512		# row 4
	sw $t4, 28($t3)
	sw $t1, 32($t3)
	sw $t0, 36($t3)
	sw $t1, 40($t3)
	sw $t1, 44($t3)
	
	jr $ra

########################## PAINT LEFT REX ###########################

Draw_Left_REX:
	li $t0, EYE_COLOUR
	li $t1, REX_COLOUR_MAIN
	li $t2, REX_COLOUR_MOUTH
	j Load_Left_REX_Position

Draw_Left_REX_Hit:
	li $t0, EYE_COLOUR
	li $t1, REX_COLOUR_HIT
	li $t2, REX_COLOUR_MOUTH
	j Load_Left_REX_Position

Erase_Left_REX:
	li $t0, BLACK_COLOUR
	li $t1, BLACK_COLOUR
	li $t2, BLACK_COLOUR

Load_Left_REX_Position:
	# Use t8 and t9 for initial position (x, y) of the rex
	move $t8, $a0
	move $t9, $a1
	# Address Calculations
	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE

	li $t6, 3
	beq $t7, $t6, Draw_Left_Down_REX

Draw_Left_REX_End:
	sw $t1, 0($t3)			# row 1
	sw $t0, 4($t3)			# eye
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	
	addi $t3, $t3, 512		# row 2
	sw $t1, 0($t3)
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	
	addi $t3, $t3, 512		# row 3
	sw $t2, 0($t3)
	sw $t2, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	
	addi $t3, $t3, -1024
	
Draw_Left_Down_REX:
	addi $t3, $t3, 1536		# row 4
	li $t4, BLACK_COLOUR
	sw $t4, 0($t3)
	sw $t4, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 32($t3)
	
	addi $t3, $t3, 512		# row 5
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 28($t3)
	sw $t1, 32($t3)
	
	addi $t3, $t3, 512		# row 6
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	sw $t1, 28($t3)

	addi $t3, $t3, 512		# row 7
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	sw $t1, 28($t3)
	
	addi $t3, $t3, 512		# row 8
	sw $t1, 12($t3)
	sw $t1, 24($t3)
	
	addi $t3, $t3, 512		# row 9
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	
	beq $t7, $t6, Draw_Left_Down_REX_End

	jr $ra
	
Draw_Left_Down_REX_End:
	addi $t3, $t3, -1024		# row 7
	li $t4, BLACK_COLOUR
	sw $t4, 8($t3)
	sw $t1, 4($t3)
	sw $t4, -4($t3)
	sw $t4, -8($t3)
	sw $t4, -12($t3)
	
	addi $t3, $t3, -512		# row 6
	sw $t2, -12($t3)
	sw $t2, -8($t3)
	sw $t1, -4($t3)
	sw $t1, 0($t3)
	
	addi $t3, $t3, -512		# row 5
	sw $t1, -12($t3)
	sw $t1, -8($t3)
	sw $t1, -4($t3)
	sw $t1, 0($t3)
	sw $t1, 4($t3)
	
	addi $t3, $t3, -512		# row 4
	sw $t4, 4($t3)
	sw $t1, 0($t3)
	sw $t0, -4($t3)
	sw $t1, -8($t3)
	sw $t1, -12($t3)
	jr $ra
	
########################## DRAW REX SHOOT ###########################
	
Draw_REX_Shoot:
	move $t8, $a0			# x
	move $t9, $a1			# y
	move $t7, $a2			# status
	
	mul $t3, $t9, 512		# Address Calculations
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE
	
	li $t0, BLACK_COLOUR
	li $t1, REX_COLOUR_MAIN
	li $t2, REX_COLOUR_MOUTH
	
	beqz $t7, Right_Up_REX_Shoot
	li $t4, 1
	beq $t4, $t7, Right_Down_REX_Shoot
	li $t4, 2
	beq $t4, $t7, Left_Up_REX_Shoot
	li $t4, 3
	beq $t4, $t7, Left_Down_REX_Shoot

Right_Up_REX_Shoot:
	addi $t3, $t3, 1024		# row 3
	sw $t0, 28($t3)
	sw $t0, 32($t3)
	addi $t3, $t3, 512		# row 4
	sw $t2, 28($t3)
	sw $t2, 32($t3)
	jr $ra

Right_Down_REX_Shoot:
	addi $t3, $t3, 2560		# row 6
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	
	addi $t3, $t3, 512		# row 7
	sw $t1, 36($t3)
	sw $t2, 40($t3)
	sw $t2, 44($t3)
	jr $ra

Left_Up_REX_Shoot:
	addi $t3, $t3, 1024		# row 3
	sw $t0, 0($t3)
	sw $t0, 4($t3)
	addi $t3, $t3, 512		# row 4
	sw $t2, 0($t3)
	sw $t2, 4($t3)
	jr $ra

Left_Down_REX_Shoot:
	addi $t3, $t3, 2560		# row 6
	sw $t0, -12($t3)
	sw $t0, -8($t3)
	
	addi $t3, $t3, 512		# row 7
	sw $t1, -4($t3)
	sw $t2, -8($t3)
	sw $t2, -12($t3)
	jr $ra

#####################################################################

######################## UPDATE REX SHOT ############################

Update_REX_Shoot:
	la $t6, REX_Shot_X
	la $t7, REX_Shot_Y
	la $t5, REX_Shot_Sign
	
	li $t0, BLACK_COLOUR		# Load Background colour
	li $t1, REX_SHOOT_COLOUR	# Load shot colour
	
	li $t2, 3
	
Update_Shot:
	lw $t8, 0($t6)			# x position of the first shot
	lw $t9, 0($t7)			# y position of the first shot
	
	addi $t2, $t2, -1		# i --
	
	li $t4, 128
	beq $t4, $t8, Update_Shot_End	# If x == -1, check the next shoot
	li $t4, -1
	beq $t4, $t8, Update_Shot_End	# If x == 128, check the next shoot
	
	mul $t3, $t9, 512		# Address Calculations
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE

	sw $t0, 0($t3)			# Erase the old shot
	
	lw $t4, 0($t5)			# Get the direction of the shot
	bltz $t4, Left_Shoot
	j Right_Shoot
	
Left_Shoot:
	lw $t4, -4($t3)			# Check the colour on next pixel, if not black, hit something
	bne $t4, $t0, REX_Shot_Hit_Something
	
	addi $t8, $t8, -1		# x --
	bltz $t8, Update_Shot_End	# If shot out of screen, disregard
	sw $t1, -4($t3)			# Elase draw the new shot
	j Update_Shot_End

Right_Shoot:
	lw $t4, 4($t3)			# If next pixel not black, hit something
	bne $t4, $t0, REX_Shot_Hit_Something
	
	addi $t8, $t8, 1		# x ++
	li $t4, 128
	beq $t8, $t4, Update_Shot_End	# If shot out of screen, disregard
	sw $t1, 4($t3)			# else draw the new shot
	j Update_Shot_End

REX_Shot_Hit_Something:
	li $t8, -1			# This shot now gone

Update_Shot_End:
	sw $t8, 0($t6)			# Update the x position of the shoot
	
	addi $t5, $t5, 4
	addi $t6, $t6, 4
	addi $t7, $t7, 4
	
	bgtz $t2, Update_Shot
	jr $ra




########################### UPDATE CACTUS ###########################	
Update_Cactus:
	addi $sp, $sp, -4		# push $ra onto the stack
	sw $ra, 0($sp)

	la $t6, Cactus_X		# Store the address of cactus information
	la $t7, Cactus_Y
	la $t5, Cactus_HP
	
	li $t2, 4			# i = 4

Update_Cactus_Loop:
	addi $t2, $t2, -1		# i --
	
	lw $t4, 0($t5)			# Get the HP of the first Cactus
	beqz $t4, Update_Cactus_End	# If HP = 0, no need to update the cactus
	
	lw $t8, 0($t6)			# x
	lw $t9, 0($t7)			# y
	jal Check_Cactus		# Else check if cactus got hit
	
Update_Cactus_End:
	addi $t6, $t6, 4
	addi $t7, $t7, 4
	addi $t5, $t5, 4
	bgtz $t2, Update_Cactus_Loop

	lw $ra, 0($sp)			# pop $ra off the stack
	addi $sp, $sp, 4		# reclaim space
	jr $ra

##################### CHECK IF CACTUS BEEN SHOT #####################
Check_Cactus:
	mul $t3, $t9, 512		# Address Calculations
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE
	
	li $t0, REX_SHOOT_COLOUR
	lw $t1, 4($t3)			# check row 1
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 20($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# check row 2
	lw $t1, 4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 20($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 3
	lw $t1, -4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 28($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 4
	lw $t1, -4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 28($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 5
	lw $t1, 0($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 28($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 6
	lw $t1, 4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 20($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 7
	lw $t1, 4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 20($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 8
	lw $t1, 4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 20($t3)
	beq $t0, $t1, Cactus_Got_Hit
	
	addi $t3, $t3, 512		# row 9
	lw $t1, 4($t3)
	beq $t0, $t1, Cactus_Got_Hit
	lw $t1, 20($t3)
	beq $t0, $t1, Cactus_Got_Hit
	j Draw_Cactus
	
Cactus_Got_Hit:
	lw $t4, 0($t5)			# Get the current HP
	addi $t4, $t4, -1		# HP - 1
	sw $t4, 0($t5)			# Update the new HP
	beqz $t4, Erase_Cactus		# If HP = 0, erase the cactus
	j Draw_Cactus

########################## DRAW/ERASE CACTUS ########################
Draw_Cactus:
	li $t0, EYE_COLOUR
	li $t1, CACTUS_COLOUR
	j Paint_Cactus
	
Erase_Cactus:
	li $t0, BLACK_COLOUR
	li $t1, BLACK_COLOUR

Paint_Cactus:
	mul $t3, $t9, 512		# Address Calculations
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE

	sw $t1, 8($t3)			# row 1
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	addi $t3, $t3, 512		# row 2
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	addi $t3, $t3, 512		# row 3
	sw $t1, 0($t3)
	sw $t0, 8($t3)
	sw $t1, 12($t3)
	sw $t0, 16($t3)
	sw $t1, 24($t3)
	
	addi $t3, $t3, 512		# row 4
	sw $t1, 0($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 24($t3)
	
	addi $t3, $t3, 512		# row 5
	sw $t1, 4($t3)
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	sw $t1, 20($t3)
	sw $t1, 24($t3)
	
	addi $t3, $t3, 512		# row 6
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	addi $t3, $t3, 512		# row 7
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	addi $t3, $t3, 512		# row 8
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	addi $t3, $t3, 512		# row 9
	sw $t1, 8($t3)
	sw $t1, 12($t3)
	sw $t1, 16($t3)
	
	jr $ra




########################## UPDARE MUSHROOM ##########################
Update_Mushroom:
	addi $sp, $sp, -4		# push $ra onto the stack
	sw $ra, 0($sp)

	la $t6, Mushroom_X
	la $t7, Mushroom_Y
	la $t5, Mushroom_HP
	la $t4, Mushroom_Shot
	
	li $t2, 3			# i

Update_Mushroom_Loop:
	addi $t2, $t2, -1		# i --
	lw $t0, 0($t5)			# Get the HP of the first Cactus
	beqz $t0, Update_Mushroom_End	# If HP = 0, no need to update the cactus
	
	lw $t8, 0($t6)			# x
	lw $t9, 0($t7)			# y

	mul $t3, $t9, 512		# Address Calculations
	mul $t0, $t8, 4
	add $t3, $t3, $t0
	addi $t3, $t3, FRAME_BASE

################### CHECK IS MUSHROOM BEEN SHOT #####################
Check_Mushroom:
	li $t0, REX_SHOOT_COLOUR
	lw $t1, -4($t3)			# check row 1
	beq $t0, $t1, Mushroom_Got_Hit
	lw $t1, 12($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	
	addi $t3, $t3, 512		# check row 2
	lw $t1, -4($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	lw $t1, 12($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	
	addi $t3, $t3, 512		# row 3
	lw $t1, 0($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	lw $t1, 8($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	
	addi $t3, $t3, 512		# row 4
	lw $t1, 0($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	lw $t1, 8($t3)
	beq $t0, $t1, Mushroom_Got_Hit
	
	addi $t3, $t3, -1536
	j Draw_Mushroom
	
Mushroom_Got_Hit:
	mul $t3, $t9, 512		# Address Calculations
	mul $t0, $t8, 4
	add $t3, $t3, $t0
	addi $t3, $t3, FRAME_BASE

	lw $t0, 0($t5)			# Get the current HP
	addi $t0, $t0, -1		# HP - 1
	sw $t0, 0($t5)			# Update the new HP
	beqz $t0, Erase_Mushroom	# If HP = 0, erase the cactus

####################### DRAW/ERASE MUSHROOM #########################
Draw_Mushroom:
	li $t0, MUSHROOM_MAIN
	li $t1, MUSHROOM_DOT
	
	sw $t1, 0($t3)			# row 1
	sw $t0, 4($t3)
	sw $t0, 8($t3)
	
	addi $t3, $t3, 512		# row 2
	sw $t0, 0($t3)
	sw $t0, 4($t3)
	sw $t1, 8($t3)
	
	li $t0, STEM_COLOUR
	addi $t3, $t3, 512		# row 3
	sw $t0, 4($t3)
	
	addi $t3, $t3, 512		# row 4
	sw $t0, 4($t3)
	
	j Update_Mushroom_Shoot
	
Erase_Mushroom:
	li $t0, BLACK_COLOUR
	sw $t0, 0($t3)			# row 1
	sw $t0, 4($t3)
	sw $t0, 8($t3)
	
	addi $t3, $t3, 512		# row 2
	sw $t0, 0($t3)
	sw $t0, 4($t3)
	sw $t0, 8($t3)

	addi $t3, $t3, 512		# row 3
	sw $t0, 4($t3)
	
	addi $t3, $t3, 512		# row 4
	sw $t0, 4($t3)
	
	addi $t9, $t9, 2		# y += 2
	lw $t1, 0($t4)			# Check the x position of mushroom shot
	
	mul $t3, $t9, 512		# Address Calculations
	mul $t0, $t1, 4
	add $t3, $t3, $t0
	addi $t3, $t3, FRAME_BASE
	
	li $t0, BLACK_COLOUR
	sw $t0, 0($t3)			# Erase the shot
	
	j Update_Mushroom_End

####################### UPDATE MUSHROOM SHOT ########################	
Update_Mushroom_Shoot:
	addi $t9, $t9, 2		# y += 2
	lw $t1, 0($t4)			# Check the x position of mushroom shot
	
	mul $t3, $t9, 512		# Address Calculations
	mul $t0, $t1, 4
	add $t3, $t3, $t0
	addi $t3, $t3, FRAME_BASE
	
	li $t0, BLACK_COLOUR
	sw $t0, 0($t3)			# Erase the old shot
	
	beqz $t1, Reset_Shoot		# If x == 0, reset the left shot (mushroom shoot again)
	li $t0, 127
	beq $t0, $t1, Reset_Shoot	# If x == 127, reset the right shot
	
	beqz $t2, Mushroom_Right_Shoot	# i ($t2) == 0, right shoot
	j Mushroom_Left_Shoot

Reset_Shoot:
	addi $t1, $t8, 1
	
	mul $t3, $t9, 512		# Address Calculations
	mul $t0, $t1, 4
	add $t3, $t3, $t0
	addi $t3, $t3, FRAME_BASE
	
	beqz $t2, Mushroom_Right_Shoot	# i ($t2) == 0, right shoot

Mushroom_Left_Shoot:
	move $t8, $t1
	li $t1, BLACK_COLOUR	
	lw $t0, -4($t3)			# Check the colour on next pixel, if not black, hit something
	bne $t1, $t0, Left_Shot_Hit_Something
	
	li $t1, MUSHROOM_SHOOT		# Load colour
	addi $t8, $t8, -1		# x --
	sw $t1, -4($t3)			# Else draw the new shot
	j Update_Mushroom_Shot_End

Mushroom_Right_Shoot:
	move $t8, $t1
	li $t1, BLACK_COLOUR	
	lw $t0, 4($t3)			# If next pixel not black, hit something
	bne $t1, $t0, Right_Shot_Hit_Something
	
	li $t1, MUSHROOM_SHOOT		# Load colour
	addi $t8, $t8, 1		# x ++
	sw $t1, 4($t3)			# else draw the new shot
	j Update_Mushroom_Shot_End

Left_Shot_Hit_Something:
	li $t8, 0			# Reset the shot
	j Update_Mushroom_Shot_End

Right_Shot_Hit_Something:
	li $t8, 127			# Reset the shot

Update_Mushroom_Shot_End:
	sw $t8, 0($t4)
	
Update_Mushroom_End:
	addi $t6, $t6, 4
	addi $t7, $t7, 4
	addi $t5, $t5, 4
	addi $t4, $t4, 4
	bgtz $t2, Update_Mushroom_Loop
	
	lw $ra, 0($sp)			# pop $ra off the stack
	addi $sp, $sp, 4		# reclaim space
	jr $ra




########################## UPDATE REX HP ############################		
Update_REX_HP:
	addi $sp, $sp, -4		# push $ra onto the stack
	sw $ra, 0($sp)
	
	move $t8, $a0			# x
	move $t9, $a1			# y
	move $t7, $a2			# status
	
	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE	# Address Calculations
	
	li $t0, BLACK_COLOUR

	beqz $t7, Right_Up_REX_HP
	li $t4, 1
	beq $t4, $t7, Right_Down_REX_HP
	li $t4, 2
	beq $t4, $t7, Left_Up_REX_HP
	j Left_Down_REX_HP
	
Right_Up_REX_HP:
	lw $t1, 16($t3)			# check row 1
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# check row 2
	lw $t1, 16($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 3
	lw $t1, 16($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 4
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 5
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 6
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 32($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 7
	lw $t1, 0($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 8
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 24($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 9
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 10 (bottom)
	lw $t1, 12($t3)
	jal Check_Collision
	lw $t1, 8($t3)
	jal Check_Collision
	lw $t1, 20($t3)
	jal Check_Collision
	lw $t1, 24($t3)
	jal Check_Collision
	
	j Update_REX_HP_End

Right_Down_REX_HP:
	addi $t3, $t3, 1536		# row 4
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 48($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 5
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 48($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 6
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 48($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 7
	lw $t1, 0($t3)
	jal Check_Collision
	lw $t1, 48($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 8
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 24($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 9
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 10 (bottom)
	lw $t1, 12($t3)
	jal Check_Collision
	lw $t1, 8($t3)
	jal Check_Collision
	lw $t1, 20($t3)
	jal Check_Collision
	lw $t1, 24($t3)
	jal Check_Collision
	
	j Update_REX_HP_End
	
Left_Up_REX_HP:
	lw $t1, -4($t3)			# check row 1
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# check row 2
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 3
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 4
	lw $t1, -4($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 5
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 6
	lw $t1, 0($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 7
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 32($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 8
	lw $t1, 8($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 9
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 10 (bottom)
	lw $t1, 12($t3)
	jal Check_Collision
	lw $t1, 8($t3)
	jal Check_Collision
	lw $t1, 20($t3)
	jal Check_Collision
	lw $t1, 24($t3)
	jal Check_Collision
	
	j Update_REX_HP_End

Left_Down_REX_HP:
	addi $t3, $t3, 1536		# row 4
	lw $t1, -16($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 5
	lw $t1, -16($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 6
	lw $t1, -16($t3)
	jal Check_Collision
	lw $t1, 36($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 7
	lw $t1, -16($t3)
	jal Check_Collision
	lw $t1, 32($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 8
	lw $t1, 8($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 9
	lw $t1, 4($t3)
	jal Check_Collision
	lw $t1, 28($t3)
	jal Check_Collision
	
	addi $t3, $t3, 512		# row 10 (bottom)
	lw $t1, 8($t3)
	jal Check_Collision
	lw $t1, 12($t3)
	jal Check_Collision
	lw $t1, 20($t3)
	jal Check_Collision
	lw $t1, 24($t3)
	jal Check_Collision
	
	j Update_REX_HP_End
	
REX_Got_Hit:
	la $t5, REX_HP
	lw $t4, 0($t5)			# Get the current HP
	addi $t4, $t4, -1		# HP - 1
	sw $t4, 0($t5)			# Update the new HP

	jal Draw_REX_Hit		# Draw REX got hit
	
Update_REX_HP_End:
	lw $ra, 0($sp)			# pop $ra off the stack
	addi $sp, $sp, 4		# reclaim space
	jr $ra

#################### CHECK IF REX HIT SOMETHING #####################	
Check_Collision:
	bne $t0, $t1, Pixel_Not_Empty
	jr $ra				# If the pixel is black, it's empty (fine!)

Pixel_Not_Empty:
	li $t4, GRASS_COLOUR
	bne $t4, $t1, Pixel_Not_Grass
	jr $ra				# If encounter grass, fine
	
Pixel_Not_Grass:
	li $t4, PLATFORM_COLOUR
	bne $t4, $t1, Pixel_Not_Platform
	jr $ra				# If encounter platform, fine
	
Pixel_Not_Platform:
	li $t4, REX_SHOOT_COLOUR
	bne $t4, $t1, Pixel_Not_REX_Shoot
	jr $ra				# If encounter REX shot, also fine

Pixel_Not_REX_Shoot:
	li $t4, FLAG_COLOUR
	bne $t4, $t1, Pixel_Not_REX_FLAG
	jr $ra				# If encounter flag, also fine

Pixel_Not_REX_FLAG:
	la $ra, REX_Got_Hit
	jr $ra				# If something else, got hit!




########################## CHECK IF WIN #############################

Check_Game_Win:
	move $t8, $a0			# x position of REX
	move $t9, $a1			# y position of REX
	li $t4, 6
	bgt $t8, $t4, Game_Continue	# if x > 6, not at the flag region
	li $t4, 50
	blt $t9, $t4, Game_Continue	# if y < 45, not at the flag region
	j Game_Win
 
Game_Continue:
	jr $ra

Game_Win:
	jal Reset_Screen
	li $t8, 35
	li $t9, 28

	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE	# Address Calculations
	
	li $t0, WHITE_COLOUR
	
	sw $t0, 0($t3)			# Y: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	
	sw $t0, 36($t3)			# O: start at 32($t3)
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	
	sw $t0, 68($t3)			# U: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 112
	sw $t0, 0($t3)			# W: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# I: start at 36($t3)
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 104($t3)		# !: start at 104($t3)
	sw $t0, 108($t3)
	
	addi $t3, $t3, 400		# row 2
	sw $t0, 0($t3)			# Y: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	
	sw $t0, 32($t3)			# O: start at 32($t3)
	sw $t0, 36($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# U: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 112
	sw $t0, 0($t3)			# W: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# I: start at 36($t3)
	sw $t0, 48($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 76($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 104($t3)		# !: start at 104($t3)
	sw $t0, 108($t3)
	
	addi $t3, $t3, 400		# row 3
	sw $t0, 0($t3)			# Y: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	
	sw $t0, 32($t3)			# O: start at 32($t3)
	sw $t0, 36($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# U: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 112
	sw $t0, 0($t3)			# W: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 12($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# I: start at 36($t3)
	sw $t0, 48($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 104($t3)		# !: start at 104($t3)
	sw $t0, 108($t3)
	
	addi $t3, $t3, 400		# row 4
	sw $t0, 4($t3)			# Y: start at 0($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	
	sw $t0, 32($t3)			# O: start at 32($t3)
	sw $t0, 36($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# U: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 112
	sw $t0, 0($t3)			# W: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# I: start at 36($t3)
	sw $t0, 48($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 104($t3)		# !: start at 104($t3)
	sw $t0, 108($t3)
	
	addi $t3, $t3, 400		# row 5
	sw $t0, 8($t3)			# Y: start at 0($t3)
	sw $t0, 12($t3)
	
	sw $t0, 32($t3)			# O: start at 32($t3)
	sw $t0, 36($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# U: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 112
	sw $t0, 0($t3)			# W: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# I: start at 36($t3)
	sw $t0, 48($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 104($t3)		# !: start at 104($t3)
	sw $t0, 108($t3)
	
	addi $t3, $t3, 400		# row 6
	sw $t0, 8($t3)			# Y: start at 0($t3)
	sw $t0, 12($t3)
	
	sw $t0, 32($t3)			# O: start at 32($t3)
	sw $t0, 36($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# U: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 112
	sw $t0, 0($t3)			# W: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 8($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# I: start at 36($t3)
	sw $t0, 48($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	addi $t3, $t3, 400		# row 7
	sw $t0, 8($t3)			# Y: start at 0($t3)
	sw $t0, 12($t3)
	
	sw $t0, 36($t3)			# O: start at 32($t3)
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	
	sw $t0, 72($t3)			# U: start at 68($t3)
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	
	addi $t3, $t3, 112
	sw $t0, 4($t3)			# W: start at 0($t3)
	sw $t0, 20($t3)
	
	sw $t0, 36($t3)			# I: start at 36($t3)
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 68($t3)			# N: start at 68($t3)
	sw $t0, 72($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 104($t3)		# !: start at 104($t3)
	sw $t0, 108($t3)
	
	j Check_Restart



######################## CHECK IF GAME OVER #########################

Check_Game_Over:
	la $t5, REX_HP
	lw $t4, 0($t5)			# Get the current HP
	beqz $t4, Game_Over		# If HP = 0, game over
	
	li $t0, 54
	blt $t0, $s1, Game_Over		# If REX no in the screen, game over
	
	jr $ra
	
Game_Over:
	jal Reset_Screen
	li $t8, 28
	li $t9, 28

	mul $t3, $t9, 512
	mul $t4, $t8, 4
	add $t3, $t3, $t4
	addi $t3, $t3, FRAME_BASE	# Address Calculations
	
	li $t0, WHITE_COLOUR
	
	sw $t0, 8($t3)			# G: start at 0($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# A: start at 36($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	
	sw $t0, 72($t3)			# M: start at 72($t3)
	sw $t0, 76($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	sw $t0, 132($t3)
	
	addi $t3, $t3, 152
	sw $t0, 4($t3)			# O: start at 0($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	
	sw $t0, 36($t3)			# V: start at 36($t3)
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	
	addi $t3, $t3, 360		# row 2
	sw $t0, 4($t3)			# G
	sw $t0, 8($t3)
	
	sw $t0, 40($t3)			# A
	sw $t0, 44($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 72($t3)			# M
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E
	sw $t0, 112($t3)
	
	addi $t3, $t3, 152
	sw $t0, 0($t3)			# O: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# V: start at 36($t3)
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 128($t3)
	sw $t0, 132($t3)
	
	addi $t3, $t3, 360		# row 3
	sw $t0, 0($t3)			# G
	sw $t0, 4($t3)
	
	sw $t0, 36($t3)			# A
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# M
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E
	sw $t0, 112($t3)
	
	addi $t3, $t3, 152
	sw $t0, 0($t3)			# O: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# V: start at 36($t3)
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 128($t3)
	sw $t0, 132($t3)
	
	addi $t3, $t3, 360		# row 4
	sw $t0, 0($t3)			# G
	sw $t0, 4($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# A
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# M
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	
	addi $t3, $t3, 152
	sw $t0, 0($t3)			# O: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# V: start at 36($t3)
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	sw $t0, 132($t3)
	
	addi $t3, $t3, 360		# row 5
	sw $t0, 0($t3)			# G
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# A
	sw $t0, 40($t3)
	sw $t0, 44($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# M
	sw $t0, 76($t3)
	sw $t0, 84($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E
	sw $t0, 112($t3)
	
	addi $t3, $t3, 152
	sw $t0, 0($t3)			# O: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 40($t3)			# V: start at 36($t3)
	sw $t0, 44($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	sw $t0, 56($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	
	addi $t3, $t3, 360		# row 6
	sw $t0, 4($t3)			# G
	sw $t0, 8($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# A
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# M
	sw $t0, 76($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E
	sw $t0, 112($t3)
	
	addi $t3, $t3, 152
	sw $t0, 0($t3)			# O: start at 0($t3)
	sw $t0, 4($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 44($t3)			# V: start at 36($t3)
	sw $t0, 48($t3)
	sw $t0, 52($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	
	addi $t3, $t3, 360		# row 7
	sw $t0, 8($t3)			# G
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	sw $t0, 24($t3)
	
	sw $t0, 36($t3)			# A
	sw $t0, 40($t3)
	sw $t0, 56($t3)
	sw $t0, 60($t3)
	
	sw $t0, 72($t3)			# M
	sw $t0, 76($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# E
	sw $t0, 112($t3)
	sw $t0, 116($t3)
	sw $t0, 120($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	sw $t0, 132($t3)
	
	addi $t3, $t3, 152
	sw $t0, 4($t3)			# O: start at 0($t3)
	sw $t0, 8($t3)
	sw $t0, 12($t3)
	sw $t0, 16($t3)
	sw $t0, 20($t3)
	
	sw $t0, 48($t3)			# V: start at 36($t3)
	
	sw $t0, 72($t3)			# E: start at 72($t3)
	sw $t0, 76($t3)
	sw $t0, 80($t3)
	sw $t0, 84($t3)
	sw $t0, 88($t3)
	sw $t0, 92($t3)
	sw $t0, 96($t3)
	
	sw $t0, 108($t3)		# R: start at 108($t3)
	sw $t0, 112($t3)
	sw $t0, 124($t3)
	sw $t0, 128($t3)
	sw $t0, 132($t3)

	j Check_Restart

#################### CHECK IF USER WANT TO RESTART ##################

Check_Restart:				# Determine user keypress
	li $t0, KEYPRESS_BASE
	lw $t1, 0($t0)			# Check if key pressed event happened
	bne $t1, 1, Check_Restart
	lw $t0, 4($t0)			# If happened, check which key was pressed
	
	beq $t0, 0x70, P_Pressed
	j Check_Restart

#####################################################################



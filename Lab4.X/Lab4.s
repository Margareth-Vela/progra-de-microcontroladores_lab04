    ;Archivo:	    Lab4.s
    ;Dispositivo:   PIC16F887
    ;Autor:	    Margareth Vela
    ;Compilador:    pic-as(v2.31), MPLABX V5.45
    ;
    ;Programa:	    Interrupciones y pull-ups
    ;Hardware:	    LEDs en puerto A, displays 7 seg en puerto C y D  
    ;		    & push buttons en puerto B
    ;Creado: 21 feb, 2021
    ;Última modificación: 23 feb, 2021
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscilador interno sin salidas
  CONFIG  WDTE = OFF            ; WDT disabled (reinicio dispositivo del pic)
  CONFIG  PWRTE = ON            ; PWRT enabled (espera de 72ms al iniciar)
  CONFIG  MCLRE = OFF           ; El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              ; Sin protección de código
  CONFIG  CPD = OFF             ; Sin protección de datos
  CONFIG  BOREN = OFF           ; Sin reinicio cuándo el voltaje de alimentacion baja de 4v
  CONFIG  IESO = OFF            ; Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           ; Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = ON              ; Programacion en bajo voltaje permitida

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Reinicio abajo de 4V, (BOR21V=2.1V)
  CONFIG  WRT = OFF             ; Protección de autoescritura por el programa desactivada

;-------------------------------------------------------------------------------
; Macro
;-------------------------------------------------------------------------------
resetTMR0 macro 
    banksel PORTA
    movlw   217	    ;Número inicial del tmr0
    movwf   TMR0    
    bcf	    T0IF    ; Se limpia la bandera
    endm

;-------------------------------------------------------------------------------
; Variables
;-------------------------------------------------------------------------------
PSECT udata_shr ;Share memory
    contador1:	    DS 1 ;1 byte 
    contador2:	    DS 1 ;1 byte
    W_TEMP:	    DS 1 ;1 byte
    STATUS_TEMP:    DS 1 ;1 byte

;-------------------------------------------------------------------------------
; Vector Reset
;-------------------------------------------------------------------------------
PSECT resetvector, class=code, delta=2, abs
ORG 0x0000   ;Posición 0000h para el reset
resetvector:
    goto setup
        
;-------------------------------------------------------------------------------
; Vector de interrupción
;-------------------------------------------------------------------------------
PSECT intVect, class=code, delta=2, abs
ORG 0x0004   ;Posición 0004h para el vector interrupción
push:
    movwf   W_TEMP
    swapf   STATUS, 0
    movwf   STATUS_TEMP
 
isr:
    btfsc   RBIF	; Si está encendida la bandera, entonces 
    call    int_IOCB	; incrementa o decrementa el puerto A y el display
    btfsc   T0IF        ; Si hay overflow en el TMR0,
    call    int_TMR0	; incrementa el TRM0 en el display
    
pop:
    swapf   STATUS_TEMP
    movwf   STATUS
    swapf   W_TEMP, 1
    swapf   W_TEMP, 0
    retfie
    
;-------------------------------------------------------------------------------
; Sub rutinas para interrupciones
;-------------------------------------------------------------------------------
int_IOCB:
    banksel PORTA
    btfss   PORTB, 0  ; Si está presiona el push del bit 0,
    incf    PORTA     ; incrementa el PORTA
    btfss   PORTB, 1  ; Si está presionado el push del bit 1, 
    decf    PORTA     ; decrementa el PORTA
    bcf	    RBIF      ; Se limpia la bandera de IOC
    movwf   PORTA, 0  ; Se mueve el valor del puerto A
    call    tabla     
    movwf   PORTC     ; Se despliegue el valor del display
    return
 
int_TMR0:
    resetTMR0		 ; Se reinicia el TMR0
    incf    contador1	 ; Se incrementa la variable
    movf    contador1, 0 ; Se compara si el conteo del TMR0 ya llegó a 
    sublw   50		 ; 1000 ms
    btfss   STATUS, 2	 ; Cuando ya haya llegado, la bandera Zero se enciende
    return
    clrf    contador1	 ; Limpia la primera variable
    incf    contador2    ; Incrementa la variable para el display
    movwf   contador2, 0
    call    tabla
    movwf   PORTD        ;Se incrementa el display
    return
    
;-------------------------------------------------------------------------------
; Código Principal 
;-------------------------------------------------------------------------------
PSECT code, delta=2, abs
ORG 0x0100 ;Posición para el código
 
tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0
    andlw   0x0F
    addwf   PCL		; PC = offset + PCL 
    retlw   00111111B	;0
    retlw   00000110B	;1
    retlw   01011011B	;2
    retlw   01001111B	;3
    retlw   01100110B	;4
    retlw   01101101B	;5
    retlw   01111101B	;6
    retlw   00000111B	;7
    retlw   01111111B	;8
    retlw   01101111B	;9
    retlw   01110111B	;A
    retlw   01111100B	;b
    retlw   00111001B	;C
    retlw   01011110B	;d
    retlw   01111001B	;E
    retlw   01110001B	;F
    
setup:
    call config_reloj	; Configuración del reloj
    call config_io	; Configuración de I/O
    call config_int	; Configuración de enable interrupciones
    call config_IOC	; Configuración IOC del puerto B
    call config_tmr0    ; Configuración inicial del tmr0
    
loop:  
    goto    loop
    
;-------------------------------------------------------------------------------
; Sub rutinas de configuración
;-------------------------------------------------------------------------------
config_io:
    banksel ANSEL ;Banco 11
    clrf    ANSEL ;Pines digitales
    clrf    ANSELH
    
    banksel TRISA ;Banco 01
    movlw   0xF0 
    movwf   TRISA ;Salida del contador binario
    bsf	    TRISB, 0 ;Push button de incremento
    bsf	    TRISB, 1 ;Push button de decremento
    clrf    TRISC   ;Display 7seg contador
    clrf    TRISD   ;Display 7seg TMR0
    
    bcf	    OPTION_REG, 7 ;Habilitar pull-ups
    bsf	    WPUB, 0 
    bsf	    WPUB, 1
    
    banksel PORTA ;Banco 00
    clrf    PORTA ;Comenzar contador binario en 0
    movlw   0x00  
    call    tabla
    movwf   PORTC      ;Comenzar los display en 0 
    movwf   PORTD
    return
    
config_int:
    bsf	GIE	; Se habilitan las interrupciones globales
    bsf	RBIE	; Se habilita la interrupción de las resistencias pull-ups 
    bcf	RBIF	; Se limpia la bandera
    bsf	T0IE    ; Se habilitan la interrupción del TMR0
    bcf	T0IF    ; Se limpia la bandera
    return
    
config_reloj:
    banksel OSCCON
    bsf	    IRCF2  ;IRCF = 100 frecuencia= 1MHz
    bcf	    IRCF1
    bcf	    IRCF0
    bsf	    SCS	   ;Reloj interno
    return
    
config_IOC:
    banksel TRISA
    bsf	    IOCB, 0 ;Se habilita el Interrupt on change de los pines
    bsf	    IOCB, 1 ;
    
    banksel PORTA
    movf    PORTB, 0 ; Termina condición de mismatch
    bcf	    RBIF     ; Se limpia la bandera
    return

;-------------------------------------------------------------------------------
; Sub rutinas para TMR0
;-------------------------------------------------------------------------------
config_tmr0:
    banksel TRISA
    bcf	    T0CS    ;Reloj intero
    bcf	    PSA	    ;Prescaler al TMR0
    bsf	    PS2
    bsf	    PS1
    bcf	    PS0	    ;PS = 110  prescaler = 1:128 
    banksel PORTA
    resetTMR0       ;Se reinicia el TMR0
    return 
end
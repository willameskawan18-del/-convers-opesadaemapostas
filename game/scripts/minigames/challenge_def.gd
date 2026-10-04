class_name ChallengeDef
extends Resource
## Definição de um desafio (dados + script de lógica). Para criar um minijogo novo:
## 1) escreva um script que estenda Challenge; 2) crie um .tres com este recurso;
## 3) adicione o caminho em MinigameManager.CHALLENGES.

@export var id := ""
@export var title := ""
@export var tagline := ""
@export_multiline var rules := ""
@export var color := Color.WHITE
@export var logic: Script
## "choice" (botões), "bid" (valor), "reaction" (tempo de reação) ou "none" (sem decisão)
@export var input := "choice"
## Se false, não entra no sorteio das rodadas normais (ex.: eventos e ALL WIN)
@export var in_rotation := true

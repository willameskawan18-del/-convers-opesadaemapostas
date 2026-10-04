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
## Entrada padrão: "choice" (botões), "bid" (lance), "reaction", "precision", "targets",
## "memory", "race" ou "none" (sem decisão). Desafios com etapas podem trocar por etapa.
@export var input := "choice"
## "conhecimento", "habilidade", "risco", "social" ou "especial" (eventos/ALL WIN)
@export var category := "risco"
## Se false, não entra no sorteio das rodadas normais (ex.: eventos e ALL WIN)
@export var in_rotation := true
## Rodada mínima para aparecer (ex.: DERRUBE O REI só depois que há um líder claro)
@export var min_round := 1

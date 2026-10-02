# BET TYCOON — Da Banca ao Cassino

Jogo 3D de simulação/tycoon feito em **Godot 4.7** (compatível com 4.3+).
Todo dinheiro e todas as apostas são fictícios.

## Como jogar
1. Instale o Godot 4.7 (versão padrão, não precisa da .NET).
2. No Gerenciador de Projetos do Godot clique em **Importar** e selecione `game/project.godot`.
3. Clique em **Importar e Editar** e depois aperte **F5** (ou o botão ▶ no canto superior direito).

## Controles
| Tecla | Ação |
|---|---|
| WASD / setas | Andar |
| Shift | Correr |
| Espaço | Pular |
| Mouse | Câmera |
| E | Interagir |
| TAB | Celular |
| B | Administração |
| T | Velocidade do tempo (x1/x2/x4) |
| V | Alternar 3ª/1ª pessoa |
| F5 / F9 | Salvar / Carregar rápido |
| ESC | Pausa / fechar janelas |
| F12 | Painel de debug (só rodando pelo editor) |

## Testes automáticos
```
godot --headless --path game -s res://tests/run_tests.gd      # simulação
godot --headless --path game res://tests/smoke_test.tscn      # cena completa
```

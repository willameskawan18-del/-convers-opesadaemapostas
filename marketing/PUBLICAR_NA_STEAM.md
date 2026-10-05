# Como publicar na Steam e na Epic: passo a passo

Esta pasta tem, para cada jogo (`pesca/` e `leilao/`):

| Arquivo | Para que serve |
|---|---|
| `trailer_*.mp4` | Trailer 1920×1080, H.264 + AAC (formato aceito pela Steam e pela Epic) |
| `screenshots/*.png` | Capturas 1920×1080 (a Steam pede no mínimo 5) |
| `capsulas/header_capsule_920x430.png` | Cápsula do cabeçalho da página |
| `capsulas/small_capsule_462x174.png` | Cápsula pequena (listas, busca) |
| `capsulas/main_capsule_1232x706.png` | Cápsula principal (vitrine da home) |
| `capsulas/vertical_capsule_748x896.png` | Cápsula vertical (promoções sazonais) |
| `capsulas/library_capsule_600x900.png` | Capa na biblioteca |
| `capsulas/library_hero_3840x1240.png` | Fundo da biblioteca (sem texto, como a Steam exige) |
| `capsulas/library_logo_1280x720.png` | Logo transparente que vai por cima do hero |
| `capsulas/page_background_1438x810.png` | Fundo opcional da página |
| `capsulas/epic_*` | Tamanhos da Epic Games Store (paisagem 2560×1440 e retrato 1200×1600) |
| `capsulas/icon_256.png` | Ícone |
| `LOJA_STEAM.md` | Textos PT/EN, tags, preço, requisitos e IDs das conquistas |

> As cápsulas e o trailer foram gerados a partir do próprio jogo. Servem para abrir a página e começar a juntar wishlists já. Quando o jogo começar a vender, vale pagar um artista para refazer a **cápsula principal**: é o que mais influencia os cliques.

## 1. Steam (Steamworks)
1. Crie a conta em **partner.steamgames.com** e pague a **taxa de US$ 100 por jogo**. O valor volta depois de US$ 1.000 em vendas.
2. Preencha os dados fiscais e bancários. Como você está no Brasil, use o formulário W-8BEN.
3. Crie o app e preencha a **página da loja** com os textos de `LOJA_STEAM.md`. Envie as cápsulas, as screenshots e o trailer.
4. **Publique a página "Em breve" o quanto antes.** Wishlists são o que faz a Steam mostrar o jogo no lançamento. A meta comum é chegar a 7.000+ wishlists antes de lançar.
5. Responda o questionário de classificação **IARC** (sai a classificação para o Brasil e o resto do mundo).
6. Envie o build: exporte do Godot para Windows (preset "Windows") e suba com o **SteamPipe** (ContentBuilder do SDK).
7. Cadastre as **conquistas** com os mesmos IDs listados em `LOJA_STEAM.md`. No jogo elas já existem com esses IDs; falta só ligar ao Steamworks (GodotSteam).
8. A Valve revisa a página e o build (leva de 3 a 7 dias). Depois você escolhe a data de lançamento.

### Multiplayer pela Steam
Hoje o jogo usa conexão direta por IP, com UPnP automático e Radmin VPN como alternativa. Para ter o botão **"Convidar amigo"** da Steam é preciso o plugin **GodotSteam**. Eu não consegui baixar o plugin daqui porque o ambiente bloqueia `github.com/releases` e `codeberg.org`. Se você liberar esses domínios em *Settings → Network* do ambiente do Claude Code, eu integro em seguida.

## 2. Epic Games Store
1. Cadastre-se em **dev.epicgames.com** (portal Epic Games Publishing). Não tem taxa.
2. Preencha a página com os mesmos textos e use as imagens `epic_*`.
3. A Epic fica com 12% das vendas (a Steam fica com 30%).

## 3. O que faz um jogo assim vender (sem promessas)
**Ninguém consegue garantir vendas**, nem eu nem nenhuma loja. O que aumenta muito as chances:
- **Steam Next Fest:** lance uma **demo** gratuita durante o festival (acontece 3 vezes por ano). É a maior fonte de wishlists de graça.
- **TikTok, Shorts e Reels:** clipes de 10 a 20 segundos com o momento engraçado ou assustador. Exemplos: o tentáculo derrubando o amigo, a porta do galpão abrindo e revelando a moto, o bot provocando "Desculpa, fulano!".
- **Streamers pequenos e médios** de jogos co-op (PT-BR e inglês). Mande chaves grátis pelo Keymailer ou direto por e-mail.
- **Preço baixo e "compre um pra cada amigo":** US$ 4,99 e, se possível, um pacote de 4 cópias (Friend Pack).
- **Inglês na página.** A maior parte do público da Steam não lê português. Os textos em inglês já estão prontos.
- **Atualizações rápidas** nas primeiras semanas, ouvindo as avaliações.

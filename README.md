# Deploy portátil CS 1.6 Web

## Estado da migração

O Dockerfile agora compila engine nativo, bindings Go, engine WebAssembly e cliente CS a partir de fontes fixadas. Nenhum estágio herda outra imagem de servidor CS. **A compilação completa e uma sessão no navegador ainda precisam ser validadas.** O Compose mantém a imagem publicada anterior até essa validação; não confunda seus resultados anteriores com os deste novo Dockerfile.

## Construção independente

```sh
docker build -t cs16-web:source .
```

A compilação usa bastante disco e memória. Prefira o workflow manual `Publish source-built portable CS16 image`, que publica uma imagem separada em `ghcr.io/markzapxd/cs16-web/source-cs16:sha-<commit>`. Não atualiza automaticamente o Compose nem a produção.

### Proveniência das fontes

- Engine nativo: `https://github.com/FWGS/xash3d-fwgs`, commit `d3bc7fabeea8586f38a501b4cc6233fa0545f5f0`.
- Engine navegador: mesmo repositório, commit `f85aa0c8f7d46c27191132b44d872c8e331308de` (gitlink do projeto de referência).
- Cliente CS: `https://github.com/FWGS/cs16-client`, commit `2490c5e9b66928e86df191ec1cdd802b6357a71c` (gitlink do projeto de referência).
- Bindings Go: `https://github.com/jklenner/goxash3d-fwgs`, commit `dd563e429ad3c4a0e96ad929b1e87911d7f94c6d`. É o objeto original da revisão `dd563e429ad3` requerida no go.mod, preservado no fork.
- `vendor/server` e `vendor/engine-wrapper`: fontes do projeto `https://github.com/sealdev224/webxash3d-fwgs-cstrike`, commit `ed3ec1fc3781c5dedd1dd52c23b2d96bfed7584c`, copiadas do checkout de referência. O cliente local já continha preload Garten; a alteração de build substitui-o pelo manifesto externo. Licença preservada em `vendor/LICENSE.md`; demais licenças permanecem nas árvores recuperadas.
- Submódulos são resolvidos pelos gitlinks fixados dos commits acima. URLs desativadas `github.com/yohimik/` são redirecionadas para a rede de forks `github.com/FWGS/`; a revisão é mantida, não substituída por HEAD.
- Toolchains: Debian trixie, Go 1.25.1, Node 22, Emscripten 4.0.23 (engine) e 4.0.17 (CS), conforme receitas de referência. Tags das imagens de toolchain e dependências npm transitivas ainda não estão integralmente fixadas por digest/lock; isto não promete reprodução bit a bit.

`build/patch-source.py` remove a liberação dos ponteiros interiores de `fragment_data_block` no engine nativo. O bloco proprietário e os arrays são liberados uma única vez. O patch exige contexto único e falha se a fonte mudar. Não modifica executáveis existentes nem usa o patch binário antigo `patch.py` (arquivo legado não utilizado pelo build).

O cliente extrai o ZIP sequencialmente e carrega o manifesto `/deployment-preload.json` antes de iniciar. Erros HTTP e caminhos inválidos interrompem o preload. Não usa IndexedDB para o ZIP; o arquivo e seus dados ainda consomem memória.

## Dados externos e início

A imagem nova **não contém os dados comerciais do jogo**. No primeiro `docker compose up -d`, o serviço `game-data` baixa o release HLDS 8308 original para um volume nomeado e prepara `valve/`, `cstrike/` e o ZIP do navegador. O servidor espera a preparação terminar com sucesso. Reinícios reutilizam o volume; `docker compose down -v` remove os dados e exige novo download. Reserve aproximadamente 2 GB livres para a preparação, além das imagens.

Origem: `https://github.com/EXORTEM/hlds/releases/download/8308/hlds_build_8308.zip` (redirecionamento do repositório DevilBoy-eXe original). SHA-256 fixado: `03a1035e6a479ccf0a64e842fe0f0315f1f2f9e0160619127a61ae68cdb37df9`, medido no download completo de 433317491 bytes em 2026-10-30; o metadata GitHub não publica digest independente desse asset antigo. Checksum divergente interrompe a preparação antes da extração. Não se executam programas do arquivo baixado.

Os recursos Garten continuam separados e versionados (não envie dados comerciais para Git/GHCR):

```text
custom-content/
  cstrike/
    maps/garten_v05.bsp   # conteúdo Garten versionado é preservado
  preload.json
```

Depois da compilação e validação da imagem nova (o padrão Compose ainda mantém a versão anterior até essa validação):

```sh
CS16_IMAGE=cs16-web:source docker compose up -d
```

O Compose prepara os dados automaticamente no primeiro início. `CONTENT_DIR` permite apontar para outra pasta. O conteúdo é montado somente leitura e vinculado ao servidor/HTTP; arquivos da imagem têm precedência. Recrie o container depois de mudar a estrutura dos arquivos.

HTTP escuta em **0.0.0.0:8080** no host (27016/TCP interno). `HTTP_BIND`/`HTTP_PORT` alteram a publicação. `ADVERTISED_IP` deve ser o endereço alcançável pelos jogadores; seu padrão é `127.0.0.1`, adequado apenas a acesso local. WebRTC usa 27018/TCP e UDP, não transportados por um proxy HTTP comum. Engine nativo usa 27015/UDP interno. Não inicie em paralelo com essas mesmas portas ocupadas pela produção.

`MAP` tem padrão `garten_v05`, `MAXPLAYERS` tem padrão 16. O manifesto contém caminhos públicos relativos, por exemplo:

```json
["cstrike/maps/garten_v05.bsp", "cstrike/models/garten/exemplo.mdl"]
```

Os caminhos começam com `cstrike/`, não admitem componentes vazios ou `..`. Sem manifesto, o preload usa apenas `cstrike/maps/${MAP}.bsp`. O preload não acompanha troca de mapa durante a partida automaticamente.

Os seis modelos de veículos Garten continuam ausentes na instalação de origem. Não foram criados recursos fictícios. Adicione os recursos reais e autorizados aos caminhos necessários e ao manifesto quando disponíveis.

## Validação e limites

A migração teve conferência de acessibilidade dos commits e testes estáticos de patch/Compose. A compilação Docker completa deve ocorrer no Actions devido ao espaço local limitado. Ainda não há validação de execução, estabilidade nativa, carregamento WebAssembly ou sessão WebRTC desta imagem nova. Os resultados da imagem derivada anterior não validam esta compilação. Não troque a produção até esses testes passarem.

As licenças de software não concedem direitos sobre os dados Valve nem mapas de terceiros. Preserve avisos e cumpra os requisitos de distribuição das licenças de cada componente; os links e revisões acima identificam as fontes utilizadas.

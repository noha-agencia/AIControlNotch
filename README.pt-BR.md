# AIControlNotch

[English](README.md) · **Português (Brasil)**

**Veja quanto você já usou do seu plano de IA sem sair do trabalho: Claude, Codex e qualquer modelo que você adicionar, direto no notch do MacBook.** Chega de digitar `/usage` no terminal.

![AIControlNotch em repouso: o maior uso de dois modelos, um de cada lado do notch](docs/images/rest.png)
![O painel aberto: cada limite, com régua de uso, percentual e horário de renovação, incluindo um modelo de exemplo adicionado por script](docs/images/open.png)
![Um aviso: o Codex chegou a 90% da semana](docs/images/alert.png)

## Instalação

Você precisa de um Mac com macOS 14 ou mais novo.

### O jeito fácil: peça para a sua IA

Abra um assistente de IA que rode comandos no seu Mac, como o Claude Code ou o Codex, e cole isto:

```text
Instale o AIControlNotch no meu Mac e conecte as ferramentas de IA que eu uso. Clone https://github.com/noha-agencia/AIControlNotch.git em ~/AIControlNotch (ou atualize, se já existir) e siga o docs/install-with-ai.md dessa pasta passo a passo. Fale comigo em português e me pergunte antes de mudar qualquer coisa no meu sistema.
```

Ela confere o seu Mac, compila e instala o app, conecta o Claude e o Codex e ajuda a conectar as suas outras ferramentas de IA. Ela pergunta antes de cada mudança. Os passos que ela segue estão no [docs/install-with-ai.md](docs/install-with-ai.md) (em inglês, escrito para a IA).

### À mão

Instale as Command Line Tools se ainda não tiver (`xcode-select --install`) e rode:

```bash
git clone https://github.com/noha-agencia/AIControlNotch.git ~/AIControlNotch
cd ~/AIControlNotch
./scripts/install.sh
```

O script confere o seu sistema, compila o app a partir do código, copia para `/Applications`, pergunta se deve abrir ao iniciar e abre o app. Como ele é compilado no seu Mac, o macOS não mostra aviso do Gatekeeper.

- **Atualizar:** `cd ~/AIControlNotch && git pull && ./scripts/install.sh`
- **Desinstalar:** `cd ~/AIControlNotch && ./scripts/uninstall.sh`. Ele pergunta antes de apagar as suas configurações e nunca mexe no `~/.claude/settings.json`.

## Conecte as suas IAs

| IA | Como conecta |
|---|---|
| **Claude** (Claude Code) | Pela barra de status do Claude Code: o Claude Code entrega a ela os limites do seu plano, e um wrapper pequeno os guarda para o app. A sua IA configura com o seu OK, ou veja [Como funciona](docs/pt-BR/how-it-works.md#barra-de-status-do-claude-code). Precisa do Claude Code num terminal com um plano do Claude. |
| **Codex** (app do ChatGPT ou CLI `codex`) | Automático. Entre no Codex uma vez. |
| **Qualquer outra IA** | Um script curto que lê o uso que a própria ferramenta já mostra no seu Mac. Peça para a sua IA escrever, ou faça você mesmo: [Adicionar um modelo](docs/pt-BR/add-a-model.md). |

Para conectar outra ferramenta depois, cole isto na sua IA (troque o nome):

```text
Conecte o Gemini ao AIControlNotch. Siga o passo 6 de https://github.com/noha-agencia/AIControlNotch/blob/main/docs/install-with-ai.md, fale comigo em português e me pergunte antes de mudar qualquer coisa.
```

Só dá para conectar ferramentas que mostram o uso no seu Mac, num arquivo ou num comando delas. Os scripts nunca raspam sites nem pedem as suas senhas.

## Recursos

- **Sempre à vista, nunca no caminho.** Em repouso, o notch mostra o maior uso de dois modelos fixados, cada um com um ponto de ritmo.
- **Passe o mouse para ver tudo.** O painel aberto lista cada limite de cada modelo, até 6 modelos: régua de uso, percentual e quando renova.
- **Ponto de ritmo: "vai durar até renovar?"** Verde: folga. Amarelo: no limite. Vermelho: acaba antes de renovar. Cinza: dado com mais de 30 minutos.
- **Avisos a cada 10 pontos.** Quando qualquer limite passa de 10%, 20% e assim por diante até 100%, o notch mostra quanto resta e quando renova, inclusive sobre apps em tela cheia.
- **Qualquer modelo, do seu jeito.** Um modelo adicionado por script ganha o mesmo ponto de ritmo e os mesmos avisos.
- **Inglês e português**, conforme o idioma do sistema. Em um Mac sem notch, ele fica no centro do topo da tela.

Clique com o botão direito no notch para **Atualizar agora**, **Configurar modelos…**, **Recarregar modelos** e **Abrir ao iniciar**. Não há ícone no Dock: o notch é o app.

## Privacidade, em resumo

- Tudo roda no seu Mac. Sem telemetria, sem analytics, sem atualização automática. **Nada é enviado para a Noha nem para ninguém.**
- **O app não faz nenhuma requisição de rede própria** e nunca lê login, token nem senha.
- **Claude:** só os limites que o próprio Claude Code entrega à barra de status, guardados por um wrapper pequeno no seu Mac.
- **Codex:** o app pede os números ao Codex local; o Codex fala com a OpenAI com o login dele. O app nunca lê o `~/.codex/auth.json`.
- **Scripts** rodam localmente, sem shell, com ambiente mínimo e com as suas permissões.

Os detalhes estão em [Como funciona](docs/pt-BR/how-it-works.md) e no [SECURITY.md](SECURITY.md) (em inglês).

## Ajuda

- [Solução de problemas](docs/pt-BR/troubleshooting.md)
- [Como funciona](docs/pt-BR/how-it-works.md): fontes dos dados, o que fica guardado, a barra de status do Claude Code, menu e linha de comando
- [Adicionar um modelo](docs/pt-BR/add-a-model.md): formato e regras dos scripts
- Algo errado? Abra um [relato de bug](https://github.com/noha-agencia/AIControlNotch/issues/new/choose).

## Contribuir

Relatos de bug, scripts de novos modelos e pull requests são bem-vindos. Leia o [CONTRIBUTING.md](CONTRIBUTING.md) antes. Para relatar um problema de segurança, veja o [SECURITY.md](SECURITY.md).

## Licença

[MIT](LICENSE), Copyright (c) 2026 Noha.

## Aviso

O AIControlNotch é um projeto independente. Não é afiliado, endossado nem patrocinado pela Anthropic ou pela OpenAI. Claude, Claude Code, Codex e ChatGPT são marcas de seus donos. Os nomes aparecem só para identificar os serviços de onde o app lê os números, e nenhum logo deles é incluído.

---

Feito pela [Noha](https://nohaoficial.com.br), uma agência brasileira que cria ferramentas e IA sob medida para times.

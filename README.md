# 📚 Biblioteca Pessoal (Ruby CLI)

Sistema de terminal para gerenciar sua biblioteca pessoal: cadastre livros, acompanhe o que está
lendo, avalie com estrelas, busque por vários critérios e veja estatísticas da coleção.
Os dados ficam salvos em JSON entre uma execução e outra.

Desafio da formação Ruby da Rocketseat (back-end, nível iniciante).

## ▶️ Como rodar

Precisa do Ruby 3.2 ou mais novo e do Bundler.

```bash
bundle install
bundle exec ruby bin/biblioteca --exemplo
```

O `--exemplo` carrega 15 livros de exemplo na primeira vez (só se a biblioteca estiver vazia).
Depois, rode sem ele:

```bash
bundle exec ruby bin/biblioteca
```

Os dados ficam em `data/biblioteca.json`. Para usar outro arquivo, defina `BIBLIOTECA_ARQUIVO=outro.json`.

Sem Ruby instalado, dá para rodar com Docker:

```bash
docker run --rm -it -v "$PWD:/app" -w /app ruby:3.3-slim sh -c "bundle install && ruby bin/biblioteca --exemplo"
```

## 💻 Como fica

```
📚 Biblioteca Pessoal
15 livro(s) · salvo em biblioteca.json

? O que você quer fazer?
‣ 📖 Cadastrar livro
  📚 Listar livros
  🔎 Ver detalhes de um livro
  🔍 Buscar livros
  🧪 Busca avançada (combinar filtros)
  ✏️  Editar livro
  🗑️  Remover livro
  📊 Estatísticas
  🚪 Sair
```

```
┌────┬─────────────────────────────────┬───────────────────┬──────┬───────────────────┬────────────┬───────────┐
│  # │ Título                          │ Autor             │  Ano │ Categoria         │ Status     │ Avaliação │
├────┼─────────────────────────────────┼───────────────────┼──────┼───────────────────┼────────────┼───────────┤
│  6 │ 1984                            │ George Orwell     │ 1949 │ Distopia          │ ● Lido     │ ★★★★★     │
│ 13 │ Clean Code                      │ Robert C. Martin  │ 2008 │ Programação       │ ◐ Lendo    │ —         │
│  1 │ Duna                            │ Frank Herbert     │ 1965 │ Ficção científica │ ○ Não lido │ —         │
│  9 │ Memórias Póstumas de Brás Cubas │ Machado de Assis  │ 1881 │ Romance           │ ◐ Lendo    │ —         │
└────┴─────────────────────────────────┴───────────────────┴──────┴───────────────────┴────────────┴───────────┘
```

No terminal o status aparece colorido: cinza para "Não lido", amarelo para "Lendo" e verde para "Lido".

## ✅ Funcionalidades

### Livros

- **Cadastro:** título e autor são obrigatórios. Ano, ISBN, categoria e observações são opcionais.
  O status começa como "Não lido", e só livros lidos podem receber de 1 a 5 estrelas;
- **Validação:** ano entre 1 e o ano atual, ISBN com 10 ou 13 dígitos, status e avaliação válidos.
  O formulário avisa na hora, e o modelo valida de novo antes de salvar;
- **Listagem:** tabela com código, título, autor, ano, categoria, status (com cor e ícone) e estrelas;
- **Detalhes:** mostra todos os campos, inclusive ISBN e observações;
- **Edição:** qualquer campo pode ser alterado. Os campos mudados ficam marcados com `*` até você salvar,
  e você também pode cancelar a edição;
- **Remoção:** mostra o livro e pede confirmação (`s/N`). Enter cancela.

### Buscas

- **Simples:** por título ou autor (parte do texto), ano, categoria, status ou avaliação (exata, como `5`,
  ou por faixa, como `3-5`). As buscas não diferenciam maiúsculas nem acentos;
- **Avançada:** marque vários critérios e o livro precisa atender a todos. Por exemplo,
  "Ficção científica" + "Não lido", ou "5 estrelas" + autor "Asimov";
- **Filtros prontos:** ficção científica não lida, lendo agora, favoritos, bem avaliados, clássicos
  (antes de 1950), lidos sem avaliação e sem categoria.

### Estatísticas

- **Resumo geral:** total de livros, distribuição por status e por categoria, e média das avaliações;
- **Por autor:** quantidade de livros de cada autor, do maior para o menor;
- **Por década:** livros agrupados por década, em ordem cronológica, com gráfico de barras;
- **Top livros:** ranking dos livros lidos e avaliados, da maior para a menor nota.

## 🧠 Conceitos de Ruby aplicados

| Conceito | Onde |
| --- | --- |
| **Classes e herança** | `Livro < Registro`: `Registro` guarda id e datas e define o contrato de validação (`#erros`) |
| **Composição** | Todo `Livro` tem um `Autor`. Autores iguais ignoram maiúsculas e acentos (`eql?`/`hash`) |
| **Encapsulamento** | `Livro` é imutável (`freeze`). Editar cria um livro novo, e o `Acervo` só troca se for válido |
| **Lambdas** | Cada método de `Filtros` devolve uma lambda. `Filtros.todos`, `algum` e `negar` combinam lambdas |
| **Procs e blocos** | Filtros prontos com `proc`, `&:simbolo` e `acervo.filtrar(...) { \|livro\| ... }` |
| **Callbacks** | `acervo.ao_alterar { ... }` grava o JSON sempre que um livro é criado, editado ou removido |
| **Módulos** | `Enumerable` no `Acervo` e `Comparable` no `Autor` |
| **Arquivos e JSON** | `RepositorioJson` grava num arquivo temporário e depois o renomeia, para não corromper os dados |
| **Gems** | `tty-prompt` (menus), `tty-table` (tabelas) e `colorize` (cores) |

Exemplo de filtros combinados:

```ruby
ficcao_nao_lida = Filtros.todos(Filtros.categoria("Ficção científica"), Filtros.status(:nao_lido))
acervo.filtrar(ficcao_nao_lida)

acervo.filtrar(Filtros.avaliacao(5), Filtros.autor("Asimov"))   # 5 estrelas do Asimov
acervo.filtrar(Filtros.avaliacao(3..5)) { |livro| livro.ano < 1960 }
```

## 📁 Estrutura

```
biblioteca-pessoal/
├── bin/biblioteca               # ponto de entrada (liga JSON + acervo + CLI)
├── lib/
│   ├── biblioteca.rb
│   └── biblioteca/
│       ├── base.rb              # erros, Registro (classe base) e Texto
│       ├── autor.rb
│       ├── livro.rb
│       ├── acervo.rb            # cadastro, edição, remoção, busca e callbacks
│       ├── filtros.rb           # lambdas de busca e combinações
│       ├── estatisticas.rb
│       ├── repositorio_json.rb
│       └── cli.rb               # interface com tty-prompt, tty-table e colorize
├── data/exemplo.json            # livros de exemplo (o seu biblioteca.json fica fora do git)
└── test/                        # Minitest
```

## 🧪 Testes

```bash
bundle exec rake test
```

São 39 testes:
- validações do livro;
- cadastro, edição e remoção no acervo, e os callbacks;
- cada filtro e as combinações;
- as quatro estatísticas;
- gravação e leitura do JSON, inclusive arquivo corrompido;
- o menu de ponta a ponta, simulando o teclado com `TTY::Prompt::Test`: cadastrar, listar, buscar, combinar filtros, editar, remover com confirmação e ver estatísticas.

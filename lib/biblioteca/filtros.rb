# frozen_string_literal: true

module Biblioteca
  # Fábrica de filtros. Cada método devolve uma lambda que recebe um livro
  # e responde true/false, então os filtros podem ser guardados, combinados
  # e passados para Array#select com &.
  #
  #   ficcao_nao_lida = Filtros.todos(Filtros.categoria("Ficção científica"), Filtros.status(:nao_lido))
  #   livros.select(&ficcao_nao_lida)
  module Filtros
    module_function

    # ---------- Filtros simples ----------

    # Busca parcial, sem diferenciar maiúsculas nem acentos.
    def titulo(termo)
      contem(termo, &:titulo)
    end

    def autor(termo)
      contem(termo) { |livro| livro.autor.nome }
    end

    def ano(ano)
      ->(livro) { livro.ano == ano.to_i }
    end

    # Exato, mas sem diferenciar maiúsculas nem acentos.
    def categoria(nome)
      chave = Texto.normalizar(nome)
      ->(livro) { !livro.categoria.nil? && Texto.normalizar(livro.categoria) == chave }
    end

    def status(status)
      chave = Livro.status_de(status)
      ->(livro) { livro.status == chave }
    end

    # Aceita um número exato (5) ou uma faixa (3..5): os dois respondem a ===.
    def avaliacao(valor)
      ->(livro) { !livro.avaliacao.nil? && valor === livro.avaliacao } # rubocop:disable Style/CaseEquality
    end

    # ---------- Combinações ----------

    def todos(*filtros)
      ->(livro) { filtros.all? { |filtro| filtro.call(livro) } }
    end

    def algum(*filtros)
      ->(livro) { filtros.any? { |filtro| filtro.call(livro) } }
    end

    def negar(filtro)
      ->(livro) { !filtro.call(livro) }
    end

    # ---------- Filtros prontos (lambdas e procs) ----------

    def prontos
      {
        "Ficção científica não lida" => todos(categoria("Ficção científica"), status(:nao_lido)),
        "Lendo agora" => status(:lendo),
        "Favoritos (5 estrelas)" => avaliacao(5),
        "Bem avaliados (4 ou 5 estrelas)" => avaliacao(4..5),
        "Clássicos (publicados antes de 1950)" => ->(livro) { !livro.ano.nil? && livro.ano < 1950 },
        "Lidos e ainda sem avaliação" => proc { |livro| livro.lido? && livro.avaliacao.nil? },
        "Sem categoria" => negar(:categoria.to_proc)
      }
    end

    def contem(termo, &campo)
      chave = Texto.normalizar(termo)
      ->(livro) { Texto.normalizar(campo.call(livro)).include?(chave) }
    end
    private_class_method :contem
  end
end

# frozen_string_literal: true

module Biblioteca
  # Relatórios calculados a partir de uma lista de livros.
  class Estatisticas
    def initialize(livros)
      @livros = livros.to_a
    end

    def resumo
      avaliados = @livros.select(&:avaliado?)

      {
        total: @livros.size,
        por_status: Livro::STATUS.keys.to_h { |status| [status, @livros.count { |l| l.status == status }] },
        por_categoria: contar(@livros) { |livro| livro.categoria || "Sem categoria" },
        avaliados: avaliados.size,
        media_avaliacao: avaliados.empty? ? nil : avaliados.sum(&:avaliacao).fdiv(avaliados.size).round(1)
      }
    end

    # [["Machado de Assis", 2], ["George Orwell", 2], ...] do maior para o menor
    def por_autor
      contar(@livros) { |livro| livro.autor.nome }
    end

    # { decadas: [[1940, 2], [1950, 3]], sem_ano: 1 } em ordem cronológica
    def por_decada
      com_ano, sem_ano = @livros.partition(&:ano)
      decadas = com_ano.group_by(&:decada).transform_values(&:size).sort
      { decadas: decadas, sem_ano: sem_ano.size }
    end

    # Só livros lidos e avaliados, da maior para a menor nota.
    def top(limite = 10)
      @livros.select(&:avaliado?)
             .sort_by { |livro| [-livro.avaliacao, Texto.normalizar(livro.titulo)] }
             .first(limite)
    end

    private

    # Agrupa sem diferenciar maiúsculas/acentos e ordena por quantidade (desc) e nome.
    def contar(itens, &rotulo)
      itens.group_by { |item| Texto.normalizar(rotulo.call(item)) }
           .map { |_chave, grupo| [rotulo.call(grupo.first), grupo.size] }
           .sort_by { |nome, quantidade| [-quantidade, Texto.normalizar(nome)] }
    end
  end
end

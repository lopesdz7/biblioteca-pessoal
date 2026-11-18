# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "stringio"
require "tty/prompt/test"
require_relative "../lib/biblioteca"

String.disable_colorization = true

module Fabrica
  LIVROS = [
    { titulo: "Duna", autor: "Frank Herbert", ano: 1965, categoria: "Ficção científica", status: :nao_lido },
    { titulo: "Fundação", autor: "Isaac Asimov", ano: 1951, categoria: "Ficção científica", status: :lido, avaliacao: 5 },
    { titulo: "Eu, Robô", autor: "isaac asimov", ano: 1950, categoria: "ficcao cientifica", status: :lido, avaliacao: 4 },
    { titulo: "1984", autor: "George Orwell", ano: 1949, categoria: "Distopia", status: :lido, avaliacao: 5 },
    { titulo: "Clean Code", autor: "Robert C. Martin", ano: 2008, categoria: "Programação", status: :lendo },
    { titulo: "Sem Ano", autor: "Anônimo" }
  ].freeze

  def acervo_de_exemplo
    acervo = Biblioteca::Acervo.new
    LIVROS.each { |atributos| acervo.adicionar(atributos) }
    acervo
  end
end

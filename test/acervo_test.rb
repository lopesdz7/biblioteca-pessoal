# frozen_string_literal: true

require_relative "test_helper"

class AcervoTest < Minitest::Test
  include Biblioteca
  include Fabrica

  def test_cadastra_com_codigo_sequencial
    acervo = Acervo.new
    primeiro = acervo.adicionar(titulo: "A", autor: "X")
    segundo = acervo.adicionar(titulo: "B", autor: "X")

    assert_equal [1, 2], [primeiro.id, segundo.id]
    assert_equal 2, acervo.tamanho
  end

  def test_nao_cadastra_livro_invalido
    acervo = Acervo.new
    erro = assert_raises(ErroValidacao) { acervo.adicionar(titulo: "", autor: "") }

    assert_equal 2, erro.erros.size
    assert acervo.vazio?
  end

  def test_edita_qualquer_campo_e_mantem_o_resto
    acervo = acervo_de_exemplo
    novo = acervo.atualizar(1, status: :lido, avaliacao: 5, observacoes: "Releitura")

    assert_equal "Duna", novo.titulo
    assert novo.avaliado?
    assert_equal "Releitura", novo.observacoes
    assert_same novo, acervo.encontrar(1)
  end

  def test_edicao_invalida_nao_altera_o_livro
    acervo = acervo_de_exemplo
    original = acervo.encontrar(2)

    assert_raises(ErroValidacao) { acervo.atualizar(2, status: :lendo) } # continua com 5 estrelas
    assert_same original, acervo.encontrar(2)
  end

  def test_remove_livro
    acervo = acervo_de_exemplo
    removido = acervo.remover(1)

    assert_equal "Duna", removido.titulo
    assert_nil acervo.encontrar(1)
    assert_raises(LivroNaoEncontrado) { acervo.remover(1) }
  end

  def test_avisa_os_callbacks_a_cada_alteracao
    eventos = []
    acervo = Acervo.new.ao_alterar { |evento, livro| eventos << [evento, livro.titulo] }

    acervo.adicionar(titulo: "A", autor: "X")
    acervo.atualizar(1, titulo: "B")
    acervo.remover(1)

    assert_equal [[:adicionado, "A"], [:atualizado, "B"], [:removido, "B"]], eventos
  end

  def test_filtra_com_lambdas_e_bloco
    acervo = acervo_de_exemplo

    resultado = acervo.filtrar(Filtros.autor("asimov")) { |livro| livro.ano < 1951 }
    assert_equal ["Eu, Robô"], resultado.map(&:titulo)
  end

  def test_lista_categorias_sem_repetir
    assert_equal ["Distopia", "Ficção científica", "Programação"], acervo_de_exemplo.categorias
  end
end

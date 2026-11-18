# frozen_string_literal: true

require_relative "test_helper"
require "timeout"

# Simula o teclado com TTY::Prompt::Test.
class CLITest < Minitest::Test
  include Biblioteca
  include Fabrica

  ENTER = "\r"
  BAIXO = "\e[B"
  CIMA = "\e[A"
  ESPACO = " "
  SAIR = "#{CIMA}#{ENTER}" # o menu é circular: subir do primeiro item vai para "Sair"

  def rodar(acervo, *teclas)
    prompt = TTY::Prompt::Test.new
    prompt.input << teclas.join
    prompt.input.rewind
    saida = StringIO.new
    # Se as teclas acabarem antes do "Sair", o prompt ficaria esperando para sempre.
    Timeout.timeout(5) { CLI.new(acervo: acervo, prompt: prompt, saida: saida).executar }
    saida.string
  rescue Timeout::Error
    flunk "O menu ficou esperando mais teclas. Saída até aqui:\n#{saida.string}"
  end

  def menu(posicao)
    "#{BAIXO * posicao}#{ENTER}"
  end

  def test_cadastra_livro_lido_com_avaliacao
    acervo = Acervo.new
    texto = rodar(acervo,
                  menu(0), "Duna\n", "Frank Herbert\n", "1965\n", "\n", "Ficção científica\n", "\n",
                  "#{BAIXO * 2}#{ENTER}", ENTER, # status "Lido", avaliação 5 estrelas
                  SAIR)

    assert_includes texto, "\"Duna\" cadastrado com o código 1."
    livro = acervo.encontrar(1)
    assert_equal [1965, :lido, 5], [livro.ano, livro.status, livro.avaliacao]
  end

  def test_lista_em_tabela
    texto = rodar(acervo_de_exemplo, menu(1), SAIR)

    assert_match(/│ #\s+│ Título/, texto)
    assert_includes texto, "● Lido"
    assert_includes texto, "★★★★★"
    assert_includes texto, "6 livro(s)"
  end

  def test_busca_simples_por_autor
    texto = rodar(acervo_de_exemplo, menu(3), menu(1), "asimov\n", SAIR)

    assert_includes texto, "Busca: autor contém \"asimov\""
    assert_includes texto, "2 livro(s)"
  end

  def test_busca_avancada_combinando_status_e_categoria
    # Marca "Categoria" (4º) e "Status" (5º), escolhe "Ficção científica" e "Não lido"
    teclas = [menu(4), ENTER, "#{BAIXO * 3}#{ESPACO}#{BAIXO}#{ESPACO}#{ENTER}", menu(1), ENTER, SAIR]
    texto = rodar(acervo_de_exemplo, *teclas)

    assert_includes texto, "categoria \"Ficção científica\" e status \"Não lido\""
    assert_includes texto, "Duna"
    assert_includes texto, "1 livro(s)"
  end

  def test_edita_status_e_avaliacao
    acervo = acervo_de_exemplo
    # Livro "Clean Code" (1º em ordem alfabética: "1984" vem antes, então desce 1)
    teclas = [menu(5), menu(1), menu(6), "#{BAIXO * 2}#{ENTER}", menu(1), menu(8), SAIR]
    texto = rodar(acervo, *teclas)

    assert_includes texto, "Alterações salvas."
    livro = acervo.encontrar(5)
    assert_equal [:lido, 4], [livro.status, livro.avaliacao]
  end

  def test_remover_pede_confirmacao
    acervo = acervo_de_exemplo
    texto = rodar(acervo, menu(6), ENTER, "n\n", SAIR)
    assert_includes texto, "Remoção cancelada."
    assert_equal 6, acervo.tamanho

    texto = rodar(acervo, menu(6), ENTER, "s\n", SAIR)
    assert_includes texto, "\"1984\" foi removido."
    assert_equal 5, acervo.tamanho
  end

  def test_estatisticas_por_decada_e_top
    texto = rodar(acervo_de_exemplo, menu(7), menu(2), menu(7), menu(3), SAIR)

    assert_includes texto, "1950s"
    assert_includes texto, "Sem ano informado: 1"
    assert_match(/1º.*1984/, texto)
  end
end

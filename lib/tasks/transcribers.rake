module Transcribers
  MODELS_DIR = CACHE_DIR / "models"
  DOWNLOAD_SCRIPT = CACHE_DIR / "download-ggml-model.sh"
  DOWNLOAD_SCRIPT_URL = "https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/models/download-ggml-model.sh"

  def self.resolve(name)
    case name
    when "whisperx" then Whisperx.new
    when "whisper-cpp-large" then WhisperCppLarge.new
    when "whisper-cpp-tdrz" then WhisperCppTdrz.new
    when "sous_chef" then SousChef.new
    when "mlx" then Mlx.new
    when "mlx-diarize" then MlxDiarize.new
    when "parakeet" then Parakeet.new
    else
      abort "Unknown transcriber: #{name}. Use 'whisperx', 'whisper-cpp-large', 'whisper-cpp-tdrz', 'sous_chef', 'mlx', 'mlx-diarize', or 'parakeet'."
    end
  end

  def self.model_path(name)
    MODELS_DIR / "ggml-#{name}.bin"
  end

  class Base
    include Rake::DSL

    def prereqs = []

    def register
      raise NotImplementedError, "#{self.class}#register not implemented"
    end

    def render(json_path, txt_path)
      raise NotImplementedError, "#{self.class}#render not implemented"
    end
  end

  class Whisperx < Base
    def name = "whisperx"
    def register; end

    def call(audio_path, transcript_path)
      hf_token = ENV.fetch("HUGGING_FACE_TOKEN") { abort "Set HUGGING_FACE_TOKEN for diarization." }
      sh "uvx", "whisperx", audio_path,
        "--model", "large-v3",
        "--compute_type", "int8",
        "--device", "cpu",
        "--diarize", "--hf_token", hf_token,
        "--output_dir", File.dirname(transcript_path),
        "--output_format", "json"
    end
  end

  class WhisperCpp < Base
    # Milliseconds of silence between segments that triggers a paragraph break.
    PARAGRAPH_GAP_MS = 500

    def render(json_path, txt_path)
      data = JSON.parse(File.read(json_path))
      segments = data["transcription"]

      paragraphs = []
      current = []

      segments.each_with_index do |seg, i|
        if i > 0
          gap = seg["offsets"]["from"] - segments[i - 1]["offsets"]["to"]
          if gap >= PARAGRAPH_GAP_MS
            paragraphs << flush_paragraph(current)
            current = []
          end
        end
        current << seg
      end
      paragraphs << flush_paragraph(current) unless current.empty?

      File.write(txt_path, paragraphs.join("\n\n"))
    end

    private

    def flush_paragraph(segments)
      timestamp = segments.first["timestamps"]["from"].sub(/^00:/, "")
      text = segments.map { |s| s["text"].strip }.join(" ")
      "[#{timestamp}] #{text}"
    end

    def register_model(name)
      models_dir = MODELS_DIR
      script = DOWNLOAD_SCRIPT

      directory models_dir.to_s

      file script.to_s => CACHE_DIR.to_s do
        puts "Downloading whisper model script..."
        CookingIssues::Download.fetch(DOWNLOAD_SCRIPT_URL, script.to_s)
        script.chmod(0o755)
      end

      file Transcribers.model_path(name).to_s => [script.to_s, models_dir.to_s] do
        sh script.to_s, name, models_dir.to_s
      end
    end
  end

  class WhisperCppLarge < WhisperCpp
    MODEL = "large-v3-turbo"

    def name = "whisper-cpp-large"
    def prereqs = [Transcribers.model_path(MODEL).to_s]

    def register
      register_model(MODEL)
    end

    def call(audio_path, transcript_path)
      sh "whisper-cli",
        "--model", Transcribers.model_path(MODEL).to_s,
        "--output-json",
        "--output-file", transcript_path.delete_suffix(".json"),
        audio_path
    end
  end

  class WhisperCppTdrz < WhisperCpp
    MODEL = "small.en-tdrz"

    def name = "whisper-cpp-tdrz"
    def prereqs = [Transcribers.model_path(MODEL).to_s]

    def register
      register_model(MODEL)
    end

    def call(audio_path, transcript_path)
      sh "whisper-cli",
        "--model", Transcribers.model_path(MODEL).to_s,
        "-tdrz",
        "--output-json",
        "--output-file", transcript_path.delete_suffix(".json"),
        audio_path
    end
  end

  class SousChef < Base
    BINARY = Pathname("sous_chef/.build/release/sous_chef")
    # Sous_chef produces word-level segments, so gaps between words are
    # much shorter than sentence-level transcribers. A higher threshold
    # avoids splitting mid-sentence.
    PARAGRAPH_GAP_S = 3

    def name = "sous_chef"
    def prereqs = [BINARY.to_s]

    def register
      sources = FileList["sous_chef/**/*.swift"].exclude(%r{/\.build/})
      file BINARY.to_s => sources do
        sh "cd sous_chef && swift build -c release"
      end
    end

    def call(audio_path, transcript_path)
      sh BINARY.to_s, audio_path, transcript_path
    end

    def render(json_path, txt_path)
      segments = JSON.parse(File.read(json_path))

      paragraphs = []
      current = []

      segments.each_with_index do |seg, i|
        if i > 0 && seg["start"] && segments[i - 1]["end"]
          gap = seg["start"] - segments[i - 1]["end"]
          if gap >= PARAGRAPH_GAP_S
            paragraphs << flush_paragraph(current)
            current = []
          end
        end
        current << seg
      end
      paragraphs << flush_paragraph(current) unless current.empty?

      File.write(txt_path, paragraphs.join("\n\n"))
    end

    private

    def flush_paragraph(segments)
      timestamp = format_time(segments.first["start"])
      text = segments.map { |s| s["text"].strip }.join(" ")
      "[#{timestamp}] #{text}"
    end

    def format_time(seconds)
      return "?:??" unless seconds
      total = seconds.to_i
      h = total / 3600
      m = (total % 3600) / 60
      s = total % 60
      h > 0 ? format("%d:%02d:%02d", h, m, s) : format("%d:%02d", m, s)
    end
  end

  class Mlx < Base
    SCRIPT = Pathname("bin/mlx-transcribe")
    PARAGRAPH_GAP_S = 0.5

    def name = "mlx"
    def register; end

    def call(audio_path, transcript_path)
      sh SCRIPT.to_s, audio_path, transcript_path
    end

    def render(json_path, txt_path)
      data = JSON.parse(File.read(json_path))
      segments = data["segments"]

      paragraphs = []
      current = []

      segments.each_with_index do |seg, i|
        if i > 0
          gap = seg["start"] - segments[i - 1]["end"]
          if gap >= PARAGRAPH_GAP_S
            paragraphs << flush_paragraph(current)
            current = []
          end
        end
        current << seg
      end
      paragraphs << flush_paragraph(current) unless current.empty?

      File.write(txt_path, paragraphs.join("\n\n"))
    end

    private

    def flush_paragraph(segments)
      timestamp = format_time(segments.first["start"])
      text = segments.map { |s| s["text"].strip }.join(" ")
      "[#{timestamp}] #{text}"
    end

    def format_time(seconds)
      total = seconds.to_i
      h = total / 3600
      m = (total % 3600) / 60
      s = total % 60
      h > 0 ? format("%d:%02d:%02d", h, m, s) : format("%d:%02d", m, s)
    end
  end

  class MlxDiarize < Mlx
    def name = "mlx-diarize"

    def call(audio_path, transcript_path)
      hf_token = ENV.fetch("HUGGING_FACE_TOKEN") { abort "Set HUGGING_FACE_TOKEN for diarization." }
      sh SCRIPT.to_s, audio_path, transcript_path, "--diarize", "--hf-token", hf_token
    end

    private

    def flush_paragraph(segments)
      timestamp = format_time(segments.first["start"])
      speaker = segments.first["speaker"]
      text = segments.map { |s| s["text"].strip }.join(" ")
      speaker ? "[#{timestamp} | #{speaker}] #{text}" : "[#{timestamp}] #{text}"
    end
  end

  class Parakeet < Base
    SCRIPT = Pathname("bin/parakeet-transcribe")
    # Chunking overlap produces negative gaps between sentences, so
    # gap-based splitting doesn't work. Group by sentence count instead.
    SENTENCES_PER_PARAGRAPH = 5

    def name = "parakeet"
    def register; end

    def call(audio_path, transcript_path)
      sh SCRIPT.to_s, audio_path, transcript_path
    end

    def render(json_path, txt_path)
      data = JSON.parse(File.read(json_path))
      paragraphs = data["sentences"].each_slice(SENTENCES_PER_PARAGRAPH).map do |group|
        flush_paragraph(group)
      end

      File.write(txt_path, paragraphs.join("\n\n"))
    end

    private

    def flush_paragraph(sentences)
      timestamp = format_time(sentences.first["start"])
      text = sentences.map { |s| s["text"].strip }.join(" ")
      "[#{timestamp}] #{text}"
    end

    def format_time(seconds)
      total = seconds.to_i
      h = total / 3600
      m = (total % 3600) / 60
      s = total % 60
      h > 0 ? format("%d:%02d:%02d", h, m, s) : format("%d:%02d", m, s)
    end
  end
end

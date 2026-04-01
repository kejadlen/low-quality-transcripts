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
    else
      abort "Unknown transcriber: #{name}. Use 'whisperx', 'whisper-cpp-large', 'whisper-cpp-tdrz', 'sous_chef', or 'mlx'."
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
  end

  class Mlx < Base
    SCRIPT = Pathname("bin/mlx-transcribe")

    def name = "mlx"
    def register; end

    def call(audio_path, transcript_path)
      hf_token = ENV.fetch("HUGGING_FACE_TOKEN") { abort "Set HUGGING_FACE_TOKEN for diarization." }
      sh SCRIPT.to_s, audio_path, transcript_path, "--hf-token", hf_token
    end
  end
end

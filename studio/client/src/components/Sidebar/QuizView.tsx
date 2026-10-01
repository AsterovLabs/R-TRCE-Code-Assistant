/**
 * studio/client/src/components/Sidebar/QuizView.tsx -- Student Comprehension Quiz & Tutor
 */

import React, { useState } from 'react';
import { HelpCircle, Sparkles, CheckCircle2, XCircle, RotateCcw } from 'lucide-react';
import { QuizQuestion } from '../../types';

interface QuizViewProps {
  quiz: QuizQuestion[];
  onGenerateQuiz: () => void;
  isLoading?: boolean;
}

export const QuizView: React.FC<QuizViewProps> = ({
  quiz,
  onGenerateQuiz,
  isLoading = false
}) => {
  const [selectedAnswers, setSelectedAnswers] = useState<Record<number, number>>({});
  const [revealed, setRevealed] = useState<Record<number, boolean>>({});

  const handleSelect = (questionId: number, optionIdx: number) => {
    setSelectedAnswers(prev => ({ ...prev, [questionId]: optionIdx }));
    setRevealed(prev => ({ ...prev, [questionId]: true }));
  };

  const handleReset = () => {
    setSelectedAnswers({});
    setRevealed({});
  };

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <span>Tutor & Quiz</span>
        <button
          onClick={onGenerateQuiz}
          disabled={isLoading}
          className="flex items-center space-x-1 text-rt-mauve hover:text-rt-peach transition font-bold"
        >
          <Sparkles className="w-3 h-3" />
          <span>New Quiz</span>
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-3 space-y-4">
        {isLoading ? (
          <div className="h-40 flex items-center justify-center text-xs text-rt-text-faint">
            <div className="animate-spin mr-2">⟳</div> Synthesizing comprehension quiz...
          </div>
        ) : quiz.length === 0 ? (
          <div className="h-40 flex flex-col items-center justify-center p-6 text-center text-xs text-rt-text-muted">
            <HelpCircle className="w-8 h-8 mb-2 opacity-40 text-rt-mauve" />
            <p>Generate a quiz from the current file's functions, formulas, and pipelines.</p>
            <button
              onClick={onGenerateQuiz}
              className="mt-3 px-3 py-1.5 rounded bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-mauve border border-rt-mauve/30 font-semibold"
            >
              Generate Quiz
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between text-rt-text-muted">
              <span>{quiz.length} Questions</span>
              <button
                onClick={handleReset}
                className="flex items-center space-x-1 text-[11px] hover:text-rt-text transition"
              >
                <RotateCcw className="w-3 h-3" />
                <span>Reset</span>
              </button>
            </div>

            {quiz.map((q, idx) => {
              const selectedIdx = selectedAnswers[q.id];
              const isRevealed = revealed[q.id];
              const isCorrect = selectedIdx === q.correct_index;

              return (
                <div
                  key={q.id || idx}
                  className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1 space-y-2.5"
                >
                  <div className="font-semibold text-rt-text leading-snug">
                    <span className="text-rt-mauve mr-1 font-mono">{idx + 1}.</span>
                    {q.question}
                  </div>

                  <div className="space-y-1.5">
                    {q.options.map((opt, optIdx) => {
                      const isChosen = selectedIdx === optIdx;
                      let btnStyle = 'bg-rt-crust/60 hover:bg-rt-surface-0 border-rt-surface-1 text-rt-text-soft';

                      if (isRevealed) {
                        if (optIdx === q.correct_index) {
                          btnStyle = 'bg-rt-green/20 border-rt-green/50 text-rt-green font-semibold';
                        } else if (isChosen) {
                          btnStyle = 'bg-rt-red/20 border-rt-red/50 text-rt-red line-through';
                        }
                      }

                      return (
                        <button
                          key={optIdx}
                          onClick={() => !isRevealed && handleSelect(q.id, optIdx)}
                          disabled={isRevealed}
                          className={`w-full text-left p-2 rounded border text-[11px] transition flex items-center justify-between ${btnStyle}`}
                        >
                          <span>{opt}</span>
                          {isRevealed && optIdx === q.correct_index && (
                            <CheckCircle2 className="w-3.5 h-3.5 text-rt-green ml-2 flex-shrink-0" />
                          )}
                          {isRevealed && isChosen && optIdx !== q.correct_index && (
                            <XCircle className="w-3.5 h-3.5 text-rt-red ml-2 flex-shrink-0" />
                          )}
                        </button>
                      );
                    })}
                  </div>

                  {isRevealed && (
                    <div className="p-2 rounded bg-rt-crust text-[11px] text-rt-text-muted border-l-2 border-rt-mauve">
                      <span className="font-bold text-rt-text">Concept: </span>
                      {q.explanation}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};
